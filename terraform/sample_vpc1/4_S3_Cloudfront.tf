# ----------------------------------------------------------
# S3 Static Website Hosting with VPC Endpoint and CloudFront (Modern, Non-Deprecated)
# ----------------------------------------------------------
# This configuration creates an S3 bucket for static website hosting,
# serves a Hello World page with a timestamp, and configures a VPC S3 Gateway Endpoint
# for private access from your VPC in us-east-1. CloudFront is included for global CDN.
# Uses only non-deprecated AWS provider resources and arguments.
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

# Enforce bucket ownership and allow public access
resource "aws_s3_bucket_ownership_controls" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id
  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# S3 bucket policy to allow public read (for static website)
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = ["s3:GetObject"],
        Resource = ["${aws_s3_bucket.website.arn}/*"]
      }
    ]
  })
}

# Upload index.html with Hello World and timestamp
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website.id
  key    = "index.html"
  content = <<-EOT
    <html><body>
    <h1>Hello World from S3!</h1>
    <p>Timestamp: ${timestamp()}</p>
    </body></html>
  EOT
  content_type = "text/html"
}

# S3 Gateway VPC Endpoint for private S3 access from VPC
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.sample_vpc.id
  service_name    = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.sample_route_table1.id, aws_route_table.sample_route_table2.id]
  tags = {
    Name = "${var.prefix}-s3-endpoint"
  }
}

# CloudFront distribution for global CDN
resource "aws_cloudfront_distribution" "website_cdn" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "s3-website"
    # origin_protocol_policy removed; not valid here for S3 website endpoint
  }
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-website"
    viewer_protocol_policy = "allow-all" # Accept both HTTP and HTTPS
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
# ----------------------------------------------------------
# End of S3 Website and CloudFront configuration
# ----------------------------------------------------------
