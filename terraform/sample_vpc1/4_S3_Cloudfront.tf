# ----------------------------------------------------------
# S3 Private Static Website Hosting with CloudFront OAC (Compliant with Security Guardrails)
# ----------------------------------------------------------
# This configuration creates a private S3 bucket for static website hosting,
# serves a Hello World page with a timestamp, and configures CloudFront with
# Origin Access Control (OAC) for secure, compliant access. No public access or policy.
# ----------------------------------------------------------

# S3 bucket for static website hosting
# ----------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket = "${var.prefix}-website-bucket"
  force_destroy = true
  tags = {
    Name = "${var.prefix}-website-bucket"
  }
}

# Enforce bucket ownership and restrict public access
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

# Upload index.html with Hello World and timestamp
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website.id
  key    = "index.html"
  content = <<-EOT
    <html><body>
    <h1>Hello World from S3!</h1>
    <p id="random-message"></p>
    <script>
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
      document.getElementById('random-message').innerText = messages[Math.floor(Math.random() * messages.length)];
    </script>
    </body></html>
  EOT
  content_type = "text/html"
}

# Create CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "website_oac" {
  name                              = "${var.prefix}-website-oac"
  description                       = "OAC for private S3 website bucket"
  origin_access_control_origin_type  = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront distribution for global CDN (private S3 origin)
resource "aws_cloudfront_distribution" "website_cdn" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-website"
    origin_access_control_id = aws_cloudfront_origin_access_control.website_oac.id
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

# S3 bucket policy to allow only CloudFront OAC to GetObject
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
# ----------------------------------------------------------
# End of S3 Website and CloudFront configuration (private, compliant)
# ----------------------------------------------------------
