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