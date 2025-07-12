# Sample VPC1 Terraform Configuration

## Overview
This project provisions a secure, multi-tier AWS environment using Terraform. It includes:
- VPC with public and private subnets across two AZs
- Public and private Application Load Balancers (ALBs)
- EC2 instances for web/app
- ECS Fargate cluster with services (web, app, api) behind private ALB
- S3 bucket for static website, served via CloudFront
- CloudFront distribution with path-based routing to S3, public ALB, and private ALB/ECS
- Security groups, IAM roles, and other best practices

## Main Components
- **VPC**: 10.0.0.0/16, with public and private subnets in two AZs
- **Public Subnets**: For public ALB and bastion/EC2
- **Private Subnets**: For ECS services and private ALB
- **EC2 Instances**: Two, with Apache and custom HTML for root and /alb
- **ALBs**:
  - Public ALB: For public-facing traffic
  - Private ALB: For internal/ECS traffic
- **ECS Cluster**: Fargate, with web, app, and api services
- **S3 Bucket**: Private, for static website content
- **CloudFront**: Single distribution, routes:
  - `/` to S3
  - `/alb/*` to public ALB
  - `/web/*`, `/app/*`, `/api/*` to private ALB/ECS
- **Security Groups**: Allow HTTP/HTTPS/ICMP from anywhere, all egress
- **IAM**: Roles for EC2 and ECS

## Architecture Diagram

```
[Internet]
    |
[CloudFront]
    |-------------------|-------------------|
    |                   |                   |
  [S3]           [Public ALB]         [Private ALB]
   |                |                      |
   |           [EC2 Instances]      [ECS Services: web, app, api]
   |                |                      |
[Static Site]   [Root, /alb]        [/web, /app, /api]
```

## Notes & Best Practices
- All S3 buckets are private; CloudFront OAC is used for secure access.
- Private ALB is only accessible from within the VPC (use bastion, VPN, or SSM for testing).
- ECS services use Fargate and are deployed in private subnets.
- Security groups are open for demo; restrict in production.
- User data scripts are left-aligned and use non-indented heredocs for reliability.
- Route53 and domain_name variable are present but optional (for DNS integration).

## Testing
- **Public ALB**: Access via its DNS or through CloudFront `/alb/*` path.
- **Private ALB**: Test from a bastion or private EC2 using `curl http://<private-alb-dns>/web` etc.
- **CloudFront**: Test all paths (`/`, `/alb/`, `/web/`, `/app/`, `/api/`).
- **EC2**: SSH and check `/var/www/html/index.html` and `/var/www/html/alb/index.html`.

## Manual Actions

After Terraform apply, you must manually register a valid IP address (ENI or proxy) as a target in the NLB target group if you want to forward NLB traffic to the ALB. This is because ALB IPs are not static and cannot be managed by Terraform. 

**Steps:**
1. Identify a valid ENI or EC2 instance IP in your subnet that can proxy traffic to the ALB.
2. In the AWS Console, go to EC2 > Target Groups > [Your NLB Target Group].
3. Register the IP address as a target.
4. Ensure your proxy forwards traffic to the ALB DNS name.

_Note: This step is required for NLB-to-ALB proxy patterns. Do not use ALB IPs directly._
