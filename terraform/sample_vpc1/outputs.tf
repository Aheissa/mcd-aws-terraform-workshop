output "public_alb_dns_name" {
  value = aws_lb.sample_alb_public.dns_name
}

output "private_alb_dns_name" {
  value = aws_lb.sample_alb_private.dns_name
}

output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.website_cdn.domain_name
}

output "nlb_dns_name" {
  value = aws_lb.public_nlb.dns_name
}

output "ec2_instance1_public_dns" {
  value = aws_instance.app_instance1.public_dns
}

output "ec2_instance1_public_ip" {
  value = aws_instance.app_instance1.public_ip
}

output "ec2_instance2_public_dns" {
  value = aws_instance.app_instance2.public_dns
}

output "ec2_instance2_public_ip" {
  value = aws_instance.app_instance2.public_ip
}

# Private Security Testing Instances
output "private_instance1_private_ip" {
  value = aws_instance.private_instance1.private_ip
}

output "private_instance1_id" {
  value = aws_instance.private_instance1.id
}

output "private_instance2_private_ip" {
  value = aws_instance.private_instance2.private_ip
}

output "private_instance2_id" {
  value = aws_instance.private_instance2.id
}

# NAT Gateway Information
output "nat_gateway_public_ip" {
  value = aws_eip.nat_eip.public_ip
}

# VPC Information for Security Testing
output "vpc_id" {
  value = aws_vpc.sample_vpc.id
}

output "private_subnet1_id" {
  value = aws_subnet.sample_private_subnet1.id
}

output "private_subnet2_id" {
  value = aws_subnet.sample_private_subnet2.id
}