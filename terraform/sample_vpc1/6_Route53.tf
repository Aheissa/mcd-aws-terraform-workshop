# ----------------------------------------------------------
# SNI-Based Routing Design Notes
# ----------------------------------------------------------
# Why use dash ("-") instead of dot (".") in subdomains like www-web.example.com?
# - DNS treats each dot as a new label (subdomain). Using dashes keeps all FQDNs as direct subdomains of your main domain.
# - SNI routing and wildcard certificates (*.example.com) work with dash-based FQDNs, but not with dot-based (e.g., www.web.example.com).
# - This simplifies SNI-based routing and certificate management.
#
# Example Flows:
# User accesses https://example.com/app
#   - DNS for example.com points to CloudFront (CNAME to dxxxx.cloudfront.net)
#   - CloudFront matches /app path, forwards to origin www-app.example.com
#   - www-app.example.com is a CNAME to the Ingress Gateway (internal ALB)
#   - Ingress Gateway uses SNI (www-app.example.com) to route to the /app backend
#
# User accesses https://example.com/web
#   - CloudFront matches /web path, forwards to origin www-web.example.com
#   - SNI is www-web.example.com, routed accordingly
#
# User accesses https://example.com/api
#   - CloudFront matches /api path, forwards to origin www-api.example.com
#   - SNI is www-api.example.com, routed accordingly
#
# Summary Table:
# | User URL                | CloudFront Origin      | CNAME in Route 53                      | SNI for Ingress Gateway      |
# |-------------------------|-----------------------|----------------------------------------|------------------------------|
# | https://example.com/app | www-app.example.com   | www-app.example.com → Ingress Gateway (ALB)   | www-app.example.com          |
# | https://example.com/web | www-web.example.com   | www-web.example.com → Ingress Gateway (ALB)   | www-web.example.com          |
# | https://example.com/api | www-api.example.com   | www-api.example.com → Ingress Gateway (ALB)   | www-api.example.com          |
#
# Recommendation:
# - Use www-app.example.com, www-web.example.com, www-api.example.com as CNAMEs for SNI-based routing.
# - This is compatible with wildcard certificates and keeps DNS, SNI, and routing simple.
# ----------------------------------------------------------
# ----------------------------------------------------------
#
#
# ----------------------------------------------------------
# ----------------------------------------------------------
# 6_Route53.tf
# ----------------------------------------------------------
# Route 53 configuration for SNI-based routing with Ingress Gateway
# ----------------------------------------------------------
# 1. Hosted Zone (domain name is a variable, provide value in terraform.tfvars)
# resource "aws_route53_zone" "main" {
#   name = var.domain_name # <-- Set your domain name in terraform.tfvars
#   comment = "Primary hosted zone for SNI-based routing lab"
# }
#
# 2. CNAME records for each service FQDN, pointing to the internal ALB DNS name
# Using dash-based subdomains for SNI-based routing and wildcard cert compatibility
# resource "aws_route53_record" "web" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www-web.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_lb.sample_alb_private.dns_name]
# }
# resource "aws_route53_record" "app" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www-app.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_lb.sample_alb_private.dns_name]
# }
# resource "aws_route53_record" "api" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www-api.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_lb.sample_alb_private.dns_name]
# }
# ----------------------------------------------------------
# End of Route 53 configuration for SNI-based routing
# ----------------------------------------------------------
#
# AWS Console (GUI) Steps:
# 1. Go to Route 53 > Hosted zones > Create hosted zone. Enter your domain name.
# 2. After creation, click 'Create record', select CNAME, and enter:
#    - Name: web (or app, api)
#    - Value: <internal ALB DNS name>
#    - TTL: 300
# 3. Repeat for each service (web, app, api).
# 4. Update your domain registrar to use the Route 53 NS records if needed.
# ----------------------------------------------------------
