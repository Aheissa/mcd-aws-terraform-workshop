variable "prefix" {
  description = "Prefix to be added to all VPC resource names."
}

variable "aws_availability_zone1" {
  description = "Availability zone in which to create the service VPC Transit Gateway instance."
  type        = string
}

variable "aws_availability_zone2" {
  description = "Availability zone in which to create the service VPC Transit Gateway instance."
  type        = string
}

variable "aws_ssh_key_pair_name" {
  description = "SSH Keypair ID used for App EC2 Instances."
  type        = string
}

variable "domain_name" {
  description = "The Route 53 domain name for SNI-based routing."
  type        = string
  default     = "cxcloudlabs.click"
}


