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
  description = "AWS SSH key pair Id - used for managing/connecting to instances."
}

variable "mcd_dns_query_log_config_id" {
  description = "AWS query log configuration Id"
  type        = string
  default     = ""
}

variable "mcd_s3_bucket" {
  description = "S3 Bucket to store CloudTrail, Route53 Query Logs and VPC Flow Logs"
  type        = string
  default     = ""
}



