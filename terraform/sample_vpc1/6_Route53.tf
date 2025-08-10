# ----------------------------------------------------------
# SNI-Based Routing Design Notes
# ----------------------------------------------------------
# Why use dash ("-") instead of dot (".") in subdomains like www-web.cxcloudlabs.click?
# - DNS treats each dot as a new label (subdomain). Using dashes keeps all FQDNs as direct subdomains of your main domain.
# - SNI routing and wildcard certificates (*.cxcloudlabs.click) work with dash-based FQDNs, but not with dot-based (e.g., www.web.cxcloudlabs.click).
# - This simplifies SNI-based routing and certificate management.
#
# Example Flows:
# User accesses https://cxcloudlabs.click/app
#   - DNS for cxcloudlabs.click points to CloudFront (CNAME to dxxxx.cloudfront.net)
#   - CloudFront matches /app path, forwards to origin www-app.cxcloudlabs.click
#   - www-app.cxcloudlabs.click is a CNAME to the NLB/Egress Gateway
#   - Egress Gateway/MCD uses SNI (www-app.cxcloudlabs.click) to filter/route traffic
#
# User accesses https://cxcloudlabs.click/web
#   - CloudFront matches /web path, forwards to origin www-web.cxcloudlabs.click
#   - SNI is www-web.cxcloudlabs.click, routed accordingly
#
# User accesses https://cxcloudlabs.click/api
#   - CloudFront matches /api path, forwards to origin www-api.cxcloudlabs.click
#   - SNI is www-api.cxcloudlabs.click, routed accordingly
#
# User accesses https://cxcloudlabs.click/alb
#   - CloudFront matches /alb path, forwards to origin www-alb.cxcloudlabs.click
#   - SNI is www-alb.cxcloudlabs.click, routed accordingly
#
# User accesses https://cxcloudlabs.click/nlb
#   - CloudFront matches /nlb path, forwards to origin www-nlb.cxcloudlabs.click
#   - SNI is www-nlb.cxcloudlabs.click, routed accordingly
#
# Summary Table:
# | User URL                        | CloudFront Origin            | CNAME in Route 53                        | SNI for Egress Gateway/MCD |
# |----------------------------------|-----------------------------|------------------------------------------|---------------------------|
# | https://cxcloudlabs.click/app    | www-app.cxcloudlabs.click   | www-app.cxcloudlabs.click → NLB/Egress GW| www-app.cxcloudlabs.click |
# | https://cxcloudlabs.click/web    | www-web.cxcloudlabs.click   | www-web.cxcloudlabs.click → NLB/Egress GW| www-web.cxcloudlabs.click |
# | https://cxcloudlabs.click/api    | www-api.cxcloudlabs.click   | www-api.cxcloudlabs.click → NLB/Egress GW| www-api.cxcloudlabs.click |
# | https://cxcloudlabs.click/alb    | www-alb.cxcloudlabs.click   | www-alb.cxcloudlabs.click → Public ALB   | www-alb.cxcloudlabs.click |
# | https://cxcloudlabs.click/nlb    | www-nlb.cxcloudlabs.click   | www-nlb.cxcloudlabs.click → Public NLB   | www-nlb.cxcloudlabs.click |
#
# Recommendation:
# - Use www-app.cxcloudlabs.click, www-web.cxcloudlabs.click, www-api.cxcloudlabs.click, www-alb.cxcloudlabs.click, www-nlb.cxcloudlabs.click as CNAMEs for SNI-based routing.
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
#   name    = var.domain_name
#   comment = "Primary hosted zone for SNI-based routing lab"
# }

# 2. CNAME records for each service FQDN, pointing to the correct NLB DNS name (MCD NLB)
# resource "aws_route53_record" "app" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www-app.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = ["ciscomcd-l-ingrlfyepqxg-87ecd2011d99432e.elb.us-east-1.amazonaws.com"]
# }
# resource "aws_route53_record" "web" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www-web.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = ["ciscomcd-l-ingrlfyepqxg-87ecd2011d99432e.elb.us-east-1.amazonaws.com"]
# }
# resource "aws_route53_record" "api" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www-api.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = ["ciscomcd-l-ingrlfyepqxg-87ecd2011d99432e.elb.us-east-1.amazonaws.com"]
# }

# ----------------------------------------------------------
# End of Route 53 configuration for SNI-based routing
# ----------------------------------------------------------
#
# AWS Console (GUI) Steps:
# Step 0: Create an Outbound Route 53 Resolver Endpoint in US-VPC
# - Go to Route 53 > Outbound endpoints > Create outbound endpoint.
# - Select the US-VPC and choose at least two subnets in different AZs.
# - Create a new security group allowing UDP/TCP port 53 from the new VPC's CIDR block.
# - Complete the wizard and note the endpoint ID for use in forwarding rules.
#
# Step 1: Go to Route 53 > Hosted zones > Create hosted zone. Enter your domain name.
# Step 2: After creation, click 'Create record', select CNAME, and enter:
#    - Name: web (or app, api)
#    - Value: <internal ALB DNS name>
#    - TTL: 300
# Step 3: Repeat for each service (web, app, api).
# Step 4: Update your domain registrar to use the Route 53 NS records if needed.
# ----------------------------------------------------------
# Cross-VPC Private DNS Resolution via Transit Gateway & Route 53 Resolver
# ----------------------------------------------------------
# Step-by-step guide for enabling DNS resolution from a new VPC to a private ALB in US-VPC
# ----------------------------------------------------------

# 1. Enable DNS Resolution Support on the Transit Gateway Attachments
#    - In the AWS Console, go to VPC > Transit Gateway Attachments.
#    - For each VPC attachment (US-VPC and new VPC), select the attachment and ensure 'DNS support' is enabled.

# 2. Configure AmazonProvidedDNS in Both VPCs
#    - In the AWS Console, go to VPC > Your VPCs.
#    - For both VPCs, ensure:
#      - enableDnsSupport = true
#      - enableDnsHostnames = true
#    - These settings are usually enabled by default.

# 3. Create an Outbound Route 53 Resolver Endpoint in US-VPC
#    - Go to Route 53 > Outbound endpoints > Create outbound endpoint.
#    - Select the US-VPC and choose at least two subnets in different AZs.
#    - Create a new security group allowing UDP/TCP port 53 from the new VPC's CIDR block.
#    - Complete the wizard and note the endpoint ID for use in forwarding rules.

# 4. Create a Route 53 Resolver Rule (Forwarding Rule)
#    - Go to Route 53 > Rules > Create rule.
#    - Choose 'Forward' as the rule type.
#    - For 'Domain name', enter the domain to forward (e.g., us-east-1.elb.amazonaws.com for ALB DNS).
#    - For 'Rule action', select 'Forward'.
#    - For 'Forward to', select the outbound resolver endpoint created in US-VPC.
#    - Complete the wizard to create the rule.

# 5. Associate the Rule with the New VPC
#    - In Route 53 > Rules, select the rule you created.
#    - Click 'Associate VPCs'.
#    - Select your new VPC and confirm.
#    - Now, DNS queries for the specified domain from the new VPC will be forwarded to the US-VPC’s resolver endpoint.

# 6. Security Groups and NACLs
#    - Ensure the security group for the resolver endpoint allows inbound UDP/TCP 53 from the new VPC’s CIDR.
#    - Ensure NACLs on the subnets for the endpoints allow UDP/TCP 53 from/to the new VPC’s CIDR.

# 7. Test DNS Resolution
#    - Launch an EC2 instance in the new VPC.
#    - SSH into the instance.
#    - Run: nslookup internal-spoke1-alb-private-53107485.us-east-1.elb.amazonaws.com
#    - You should receive the private IP(s) of the ALB in the US-VPC.
# ----------------------------------------------------------
# Save this section as a technical reference for cross-VPC DNS resolution setup.
# ----------------------------------------------------------
