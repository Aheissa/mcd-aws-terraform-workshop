output "public_alb_dns_name" {
  value = module.sample_vpc.public_alb_dns_name
}

output "private_alb_dns_name" {
  value = module.sample_vpc.private_alb_dns_name
}

output "cloudfront_distribution_domain_name" {
  value = module.sample_vpc.cloudfront_distribution_domain_name
}

output "nlb_dns_name" {
  value = module.sample_vpc.nlb_dns_name
}

output "ec2_instance1_public_dns" {
  value = module.sample_vpc.ec2_instance1_public_dns
}

output "ec2_instance1_public_ip" {
  value = module.sample_vpc.ec2_instance1_public_ip
}

output "ec2_instance2_public_dns" {
  value = module.sample_vpc.ec2_instance2_public_dns
}

output "ec2_instance2_public_ip" {
  value = module.sample_vpc.ec2_instance2_public_ip
}