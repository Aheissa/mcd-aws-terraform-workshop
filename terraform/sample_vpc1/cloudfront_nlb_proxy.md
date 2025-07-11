# CloudFront to ECS via Public NLB (Proxy Pattern)

## Overview
This setup allows CloudFront to securely access ECS services running behind a private ALB by introducing a public Network Load Balancer (NLB) as a proxy. The NLB forwards traffic to the private ALB/ECS services, enabling public access via CloudFront while keeping your ECS services private.

## Architecture

```
[Internet]
   |
[CloudFront]
   |
[Public NLB]  <-- New!
   |
[Private ALB] (optional)
   |
[ECS Services (Fargate)]
```

- CloudFront uses the public NLB DNS as an origin.
- NLB forwards traffic to ECS services (directly or via private ALB).
- Security groups and health checks are configured for secure, reliable operation.

## Steps
1. Deploy a public NLB in your VPC (in public subnets).
2. Register ECS service tasks (or private ALB) as NLB targets.
3. Update security groups to allow NLB to ECS traffic.
4. Configure health checks on the NLB for ECS targets.
5. Set the NLB DNS as a CloudFront origin.

## Notes
- The NLB is public, so restrict access using security groups, WAF, or allow-lists as needed.
- Health checks should match your ECS service's health endpoint (e.g., `/` on port 80).
- This pattern is simpler than PrivateLink and works for most use cases.
- Update your Terraform code in both the ECS/ALB and CloudFront modules to reflect this change.

---
See the Terraform code in `5_ECS_ALB.tf` and `4_S3_ALB_Cloudfront.tf` for implementation details.
