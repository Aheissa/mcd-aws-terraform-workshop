# ----------------------------------------------------------
# Multi-Region Transit Gateway Peering: US (us-east-1) and EU (eu-central-1)
# This configuration enables routing between VPCs in different AWS regions
# by creating a TGW in each region and peering them together.
# ----------------------------------------------------------

# Create the Transit Gateway (TGW) in the US region (us-east-1)
# This TGW will be used for US VPC attachments and peering
resource "aws_ec2_transit_gateway" "us" {
  description         = "US Transit Gateway for inter-region peering"
  amazon_side_asn     = 64512
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = {
    Name = "us-tgw"
  }
}

# Create the Transit Gateway (TGW) in the EU region (eu-central-1)
# This TGW will be used for EU VPC attachments and peering
resource "aws_ec2_transit_gateway" "eu" {
  provider           = aws.eu
  description        = "EU Transit Gateway for inter-region peering"
  amazon_side_asn    = 64513
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = {
    Name = "eu-tgw"
  }
}

# Attach the US VPC to the US TGW
# This allows the US VPC to route traffic via the US TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "us_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.us.id
  vpc_id             = aws_vpc.sample_vpc.id
  subnet_ids         = [
    aws_subnet.sample_subnet1.id,
    aws_subnet.sample_subnet2.id
  ]
  tags = {
    Name = "us-vpc-tgw-attachment"
  }
}

# Attach the EU VPC to the EU TGW
# This allows the EU VPC to route traffic via the EU TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "eu_vpc_attachment" {
  provider           = aws.eu
  transit_gateway_id = aws_ec2_transit_gateway.eu.id
  vpc_id             = aws_vpc.eu_vpc.id
  subnet_ids         = [
    aws_subnet.eu_subnet1.id,
    aws_subnet.eu_subnet2.id
  ]
  tags = {
    Name = "eu-vpc-tgw-attachment"
  }
}

# Create a Transit Gateway Peering Attachment between US and EU TGWs
# This enables inter-region routing between the two TGWs
resource "aws_ec2_transit_gateway_peering_attachment" "us_eu" {
  transit_gateway_id      = aws_ec2_transit_gateway.us.id
  peer_transit_gateway_id = aws_ec2_transit_gateway.eu.id
  peer_region             = "eu-central-1"
  tags = {
    Name = "us-eu-tgw-peering"
  }
}

# Accept the peering attachment in the EU region
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "eu_accept" {
  provider                        = aws.eu
  transit_gateway_attachment_id    = aws_ec2_transit_gateway_peering_attachment.us_eu.id
  tags = {
    Name = "eu-accept-us-tgw-peering"
  }
}

# ----------------------------------------------------------
# RECOMMENDATION: Add routes in both VPCs and TGW route tables to enable
# inter-region traffic. You must update the VPC and TGW route tables to
# send traffic for the remote VPC CIDR via the peering attachment.
# ----------------------------------------------------------
# Example (not included here):
# - aws_route in US VPC route table for EU VPC CIDR via US TGW
# - aws_route in EU VPC route table for US VPC CIDR via EU TGW
# - aws_ec2_transit_gateway_route in each TGW's route table for remote VPC CIDR
# ----------------------------------------------------------

# Add route in US VPC route table 1 to reach EU VPC via US TGW
# This ensures that instances in subnet1 can reach the EU VPC CIDR
resource "aws_route" "us_to_eu_z1" {
  route_table_id         = aws_route_table.sample_route_table1.id
  destination_cidr_block = "10.1.0.0/16" # EU VPC CIDR
  transit_gateway_id     = aws_ec2_transit_gateway.us.id
}

# Add route in US VPC route table 2 to reach EU VPC via US TGW
# This ensures that instances in subnet2 can reach the EU VPC CIDR
resource "aws_route" "us_to_eu_z2" {
  route_table_id         = aws_route_table.sample_route_table2.id
  destination_cidr_block = "10.1.0.0/16" # EU VPC CIDR
  transit_gateway_id     = aws_ec2_transit_gateway.us.id
}

# Add route in EU VPC route table to reach US VPC via EU TGW
# Only one route table is used for both EU subnets
resource "aws_route" "eu_to_us" {
  provider               = aws.eu
  route_table_id         = aws_route_table.eu_rt.id
  destination_cidr_block = "10.0.0.0/16" # US VPC CIDR
  transit_gateway_id     = aws_ec2_transit_gateway.eu.id
}

# Add TGW route in US TGW route table to reach EU VPC via peering
# This enables the US TGW to forward traffic for the EU VPC CIDR to the peering attachment
resource "aws_ec2_transit_gateway_route" "us_to_eu" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway.us.association_default_route_table_id
  destination_cidr_block         = "10.1.0.0/16" # EU VPC CIDR
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.us_eu.id
}

# Add TGW route in EU TGW route table to reach US VPC via peering
# This enables the EU TGW to forward traffic for the US VPC CIDR to the peering attachment
resource "aws_ec2_transit_gateway_route" "eu_to_us" {
  provider                       = aws.eu
  transit_gateway_route_table_id = aws_ec2_transit_gateway.eu.association_default_route_table_id
  destination_cidr_block         = "10.0.0.0/16" # US VPC CIDR
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.us_eu.id
}
