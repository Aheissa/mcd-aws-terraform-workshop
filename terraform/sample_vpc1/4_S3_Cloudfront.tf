# ----------------------------------------------------------
# S3 Private Static Website Hosting with CloudFront OAC (Compliant with Security Guardrails)
# ----------------------------------------------------------
# 0. S3 Bucket for CloudFront Logging
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.prefix}-cloudfront-logs"
  force_destroy = true
  tags = {
    Name = "${var.prefix}-cloudfront-logs"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs_acl" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "log-delivery-write"
}

# 1. S3 Bucket and Access Controls
resource "aws_s3_bucket" "website" {
  bucket = "${var.prefix}-website-bucket"
  force_destroy = true
  tags = {
    Name = "${var.prefix}-website-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

# 2. S3 Website Content
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website.id
  key    = "index.html"
  content = <<-EOT
    <html>
    <body style="background: #f4f4f4; font-family: Arial, sans-serif;">
      <h1 style="color: #2e86de; font-size: 48px; font-family: 'Trebuchet MS', sans-serif;">Hello World from S3 Bucket1 !</h1>
      <p id="random-message" style="font-size: 32px; font-weight: bold; margin-top: 40px;"></p>
      <script>
        const colors = ["#e74c3c", "#27ae60", "#8e44ad", "#c0392b", "#2980b9", "#d35400", "#16a085", "#f39c12", "#2c3e50"];
        const messages = [
          "Free Palestine!",
          "Seize the fire!",
          "Be better every day.",
          "Focus on your goals.",
          "Eat, sleep, code, repeat.",
          "You are stronger than you think.",
          "Coffee first, then conquer the world.",
          "Stay curious, stay humble.",
          "Dream big, hustle harder.",
          "If at first you don’t succeed, call it version 1.0.",
          "Keep calm and Terraform on.",
          "The best way to get started is to quit talking and begin doing.",
          "Don’t watch the clock; do what it does. Keep going.",
          "Success is not for the lazy.",
          "You miss 100% of the shots you don’t take."
        ];
        const msg = messages[Math.floor(Math.random() * messages.length)];
        const color = colors[Math.floor(Math.random() * colors.length)];
        const el = document.getElementById('random-message');
        el.innerText = msg;
        el.style.color = color;
        el.style.textShadow = "2px 2px 8px #aaa";
      </script>
    </body>
    </html>
  EOT
  content_type = "text/html"
}

# 3. S3 Bucket Policy (OAC Only)
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {"Service": "cloudfront.amazonaws.com"},
        Action = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.website.arn}/*"],
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website_cdn.arn
          }
        }
      }
    ]
  })
}

# 4. CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "${var.prefix}-website-oac"
  description                       = "OAC for private S3 website bucket"
  origin_access_control_origin_type  = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 5. CloudFront Distribution
resource "aws_cloudfront_distribution" "website_cdn" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
  }
  origin {
    domain_name = aws_lb.sample_alb_public.dns_name
    origin_id   = "us-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-website"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern     = "/alb/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "us-alb"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  tags = {
    Name = "${var.prefix}-website-cdn"
  }
}

# 6. CloudFront Distribution for Private ALB (ECS)
resource "aws_cloudfront_distribution" "ecs_private_alb" {
  origin {
    domain_name = aws_lb.sample_alb_private.dns_name
    origin_id   = "private-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "private-alb"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      headers      = ["*"]
      cookies {
        forward = "none"
      }
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  logging_config {
    bucket = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    include_cookies = false
    prefix = "ecs-private-alb-logs/"
  }
  tags = {
    Name = "${var.prefix}-ecs-private-alb-cdn"
  }
}
# ----------------------------------------------------------
# End of S3 Website and CloudFront configuration (private, compliant)
# ----------------------------------------------------------
