# ----------------------------------------------------------
# S3 Static Website Hosting with VPC Endpoint and CloudFront
# ----------------------------------------------------------
# This configuration creates an S3 bucket for static website hosting,
# serves a Hello World page with a timestamp, and configures a VPC S3 Gateway Endpoint
# for private access from your VPC in us-east-1. CloudFront can be added for global CDN.
# ----------------------------------------------------------

# S3 bucket for static website hosting
# ----------------------------------------------------------
resource "aws_s3_bucket" "website" {
  bucket = "${var.prefix}-website-bucket"
  acl    = "public-read"
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  tags = {
    Name = "${var.prefix}-website-bucket"
  }
}

# S3 bucket policy to allow public read (for static website)
# ----------------------------------------------------------
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
# ----------------------------------------------------------
resource "aws_s3_bucket_object" "index" {
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
# Only one endpoint is needed per VPC, associate with all relevant route tables
# ----------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.sample_vpc.id
  service_name    = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_route_table.sample_route_table1.id, aws_route_table.sample_route_table2.id]
  tags = {
    Name = "${var.prefix}-s3-endpoint"
  }
}

# (Optional) CloudFront distribution for global CDN
# ----------------------------------------------------------
resource "aws_cloudfront_distribution" "website_cdn" {
  origin {
    domain_name = aws_s3_bucket.website.website_endpoint
    origin_id   = "s3-website"
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
  # No origin protocol policy strictness (default is not strict)
  # Viewer policy set to allow-all for both HTTP and HTTPS
  tags = {
    Name = "${var.prefix}-website-cdn"
  }
}
# ----------------------------------------------------------
# End of S3 Website and CloudFront configuration
# ----------------------------------------------------------
