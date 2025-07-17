# ----------------------------------------------------------
# S3 Private Static Website Hosting with CloudFront OAC
# + Public/Private ALB and Public NLB for ECS/ALB Proxy
# ----------------------------------------------------------
# This file configures:
# - S3 bucket for static website content (private, OAC only)
# - CloudFront distribution with multiple origins:
#   - S3 (private, OAC)
#   - Public ALB (for public ECS/ALB)
#   - Private ALB (for private ECS/ALB)
#   - Public NLB (for proxying CloudFront to private ALB/ECS)
#   - Custom origins for app/web/api/alb (CNAMEs)
# - Path-based routing in CloudFront to each origin
# - Logging, access controls, and security best practices
# ----------------------------------------------------------

# 0. S3 Bucket for CloudFront Logging
resource "aws_s3_bucket" "cloudfront_logs" {
  # S3 bucket for CloudFront access logs
  bucket = "${var.prefix}-cloudfront-logs"
  force_destroy = true
  tags = {
    Name = "${var.prefix}-cloudfront-logs"
  }
}

resource "aws_s3_bucket_policy" "cloudfront_logs_policy" {
  # Policy to allow CloudFront to write logs to S3
  bucket = aws_s3_bucket.cloudfront_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" },
        Action = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.cloudfront_logs.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  # Enforce object ownership for logs
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

# 1. S3 Bucket and Access Controls
resource "aws_s3_bucket" "website" {
  # S3 bucket for static website content
  bucket = "${var.prefix}-website-bucket"
  force_destroy = true
  tags = {
    Name = "${var.prefix}-website-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "website" {
  # Enforce bucket owner for website content
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  # Block all public access to website bucket
  bucket = aws_s3_bucket.website.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}

# 2. S3 Website Content
resource "aws_s3_object" "index" {
  # Main index.html for S3 website
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
          "Free Palestine! Allah Akbar!",
          "Seize the fire! Allah Akbar!",
          "Free Palestine!",
          "Seize the fire!",
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
  # Allow CloudFront OAC to access S3 website content
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
  # OAC for private S3 website bucket
  name                              = "${var.prefix}-website-oac"
  description                       = "OAC for private S3 website bucket"
  origin_access_control_origin_type  = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 5. CloudFront Distribution
resource "aws_cloudfront_distribution" "website_cdn" {
  # CloudFront distribution with S3, ALB, and NLB origins
  # Path-based routing to each origin
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
  }
  origin {
    domain_name = aws_lb.sample_alb_public.dns_name
    origin_id   = "public-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
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
  origin {
    domain_name = aws_lb.public_nlb.dns_name
    origin_id   = "nlb-ecs-proxy"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  origin {
    domain_name = "www-app.cxcloudlabs.click"
    origin_id   = "www-app"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  origin {
    domain_name = "www-web.cxcloudlabs.click"
    origin_id   = "www-web"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  origin {
    domain_name = "www-api.cxcloudlabs.click"
    origin_id   = "www-api"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  origin {
    domain_name = "www-alb.cxcloudlabs.click"
    origin_id   = "www-alb"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "match-viewer"
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
    target_origin_id = "public-alb"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern     = "/app/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "www-app"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      headers      = ["*"]
      cookies {
        forward = "none"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern     = "/web/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "www-web"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      headers      = ["*"]
      cookies {
        forward = "none"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "www-api"
    viewer_protocol_policy = "allow-all"
    forwarded_values {
      query_string = false
      headers      = ["*"]
      cookies {
        forward = "none"
      }
    }
  }
  ordered_cache_behavior {
    path_pattern     = "/nlb/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "nlb-ecs-proxy"
    viewer_protocol_policy = "allow-all"
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
  tags = {
    Name = "${var.prefix}-website-cdn"
  }
}

data "aws_caller_identity" "current" {}

#------------------------------------
# End of S3 Website and CloudFront configuration (private, compliant)
# ----------------------------------------------------------
