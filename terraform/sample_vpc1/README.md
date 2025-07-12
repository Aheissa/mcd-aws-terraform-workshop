# Sample VPC1 Terraform Configuration

## Overview
This project provisions a secure, multi-tier AWS environment using Terraform. It includes:
- VPC with public and private subnets across two AZs
- Public and private Application Load Balancers (ALBs)
- EC2 instances for web/app
- ECS Fargate cluster with services (web, app, api) behind a private ALB
- S3 bucket for static website, served via CloudFront
- CloudFront distribution with path-based routing to S3, public ALB, and private ALB/ECS (via NLB proxy)
- Security groups, IAM roles, and best practices

## Architecture Diagram
```
[Internet]
    |
[CloudFront]
    |-------------------|-------------------|
    |                   |                   |
  [S3]           [Public ALB]             [NLB]
   |                   |                    |
[Static Site]   [Root, /alb]            [Private ALB]
                                            |
                              [ECS Services: web, app, api]


```

## CloudFront Routing & Origins
- `/` → S3 (static site, private, OAC only)
- `/alb/*` → Public ALB (public-facing ECS/app traffic)
- `/web/*`, `/app/*`, `/api/*` → NLB (proxy to private ALB/ECS)

**Origins:**
- S3 (private, OAC)
- Public ALB
- NLB (forwards to private ALB)

**Security:**
- S3 is private, accessed only via CloudFront OAC
- ALBs and NLB are protected by security groups and VPC
- Path-based routing ensures correct backend for each URL pattern

## NLB and Private ALB Integration
CloudFront cannot directly communicate with a private ALB. To enable CloudFront to reach internal ECS services behind a private ALB, a public NLB is used as a proxy:
- CloudFront forwards `/web/*`, `/app/*`, `/api/*` traffic to the public NLB
- NLB forwards traffic to a proxy (ENI or EC2) in your VPC
- The proxy forwards requests to the private ALB, which routes to ECS services

**Manual Action:**
- After deployment, manually register the proxy IP in the NLB target group (do not use ALB IPs directly)

## Best Practices
- All S3 buckets are private; CloudFront OAC is used for secure access
- Private ALB is only accessible from within the VPC (use bastion, VPN, or SSM for testing)
- ECS services use Fargate and are deployed in private subnets
- Security groups are open for demo; restrict in production
- Route53 and domain_name variable are present but optional (for DNS integration)

## Testing
- **Public ALB**: Access via its DNS or through CloudFront `/alb/*` path
- **Private ALB**: Test from a bastion or private EC2 using `curl http://<private-alb-dns>/web` etc.
- **CloudFront**: Test all paths (`/`, `/alb/`, `/web/`, `/app/`, `/api/`)
- **EC2**: SSH and check `/var/www/html/index.html` and `/var/www/html/alb/index.html`

## Manual Actions
After Terraform apply, manually register a valid ENI or EC2 instance IP as a target in the NLB target group to forward NLB traffic to the private ALB.

**Steps:**
1. Identify a valid ENI or EC2 instance IP in your subnet that can proxy traffic to the ALB
2. In the AWS Console, go to EC2 > Target Groups > [Your NLB Target Group]
3. Register the IP address as a target
4. Ensure your proxy forwards traffic to the ALB DNS name

_Note: This step is required for NLB-to-ALB proxy patterns. Do not use ALB IPs directly._
