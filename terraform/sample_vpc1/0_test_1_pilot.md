# CloudFront & ALB/NLB/S3 Test URL Summary

After running `terraform apply`, fill in the output values below for your test and troubleshooting.

---

## 1. CloudFront Distribution
- Main: `https://<cloudfront_distribution_domain_name>/`
- /alb/: `https://<cloudfront_distribution_domain_name>/alb/`
- /app/: `https://<cloudfront_distribution_domain_name>/app/`
- /web/: `https://<cloudfront_distribution_domain_name>/web/`
- /api/: `https://<cloudfront_distribution_domain_name>/api/`
- /nlb/: `https://<cloudfront_distribution_domain_name>/nlb/`

## 2. Public ALB
- Test: `http://<public_alb_dns_name>/`

## 3. EC2 Public Instances
- Instance 1: `http://<ec2_instance1_public_dns>` or `http://<ec2_instance1_public_ip>`
- Instance 2: `http://<ec2_instance2_public_dns>` or `http://<ec2_instance2_public_ip>`

## 4. NLB (ECS Proxy)
- Test: `http://<nlb_dns_name>/`

## 5. Private ALB (from within VPC)
- Test: `http://<private_alb_dns_name>/app/`, `http://<private_alb_dns_name>/web/`, `http://<private_alb_dns_name>/api/`

## 6. ECS Service/Task Endpoints (if applicable)
- (Add ECS service/task endpoints here if you expose them directly, e.g., via ALB/NLB or public IP)

---

## Output Values (fill after apply)
- CloudFront Distribution: `<cloudfront_distribution_domain_name>`
- Public ALB DNS: `<public_alb_dns_name>`
- EC2 Instance 1 Public DNS: `<ec2_instance1_public_dns>`
- EC2 Instance 1 Public IP: `<ec2_instance1_public_ip>`
- EC2 Instance 2 Public DNS: `<ec2_instance2_public_dns>`
- EC2 Instance 2 Public IP: `<ec2_instance2_public_ip>`
- NLB DNS: `<nlb_dns_name>`
- Private ALB DNS: `<private_alb_dns_name>`

---

## Health Check Status (after terraform apply)
- **CloudFront**: Check in AWS Console → CloudFront → Distributions → Status should be "Deployed" and "Enabled".
- **Public ALB**: AWS Console → EC2 → Load Balancers → Health checks tab (should show healthy targets).
- **EC2 Instances**: AWS Console → EC2 → Instances → Status checks (should be "2/2 checks passed").
- **NLB**: AWS Console → EC2 → Load Balancers → Health checks tab (should show healthy targets if ALB IPs are registered).
- **Private ALB**: AWS Console → EC2 → Load Balancers → Health checks tab (should show healthy targets for ECS services).
- **ECS Services**: AWS Console → ECS → Clusters → Services → Tasks (should show running/healthy tasks).

---

## SSH to Public EC2 from Mac

1. Ensure your SSH private key is on your Mac (e.g., `~/.ssh/my-key.pem`).
2. Set permissions: `chmod 400 ~/.ssh/my-key.pem`
3. Connect:
   ```sh
   ssh -i ~/.ssh/my-key.pem ubuntu@<ec2_instance1_public_dns>
   # or
   ssh -i ~/.ssh/my-key.pem ubuntu@<ec2_instance1_public_ip>
   ```
   - Replace `ubuntu` with the correct username for your AMI (e.g., `ec2-user` for Amazon Linux, `ubuntu` for Ubuntu).

---

**Note:**
- S3 website endpoint is private and only accessible via CloudFront.
- Private ALB is only accessible from within the VPC or via a bastion host.
- NLB DNS output can be added to Terraform if not present.
