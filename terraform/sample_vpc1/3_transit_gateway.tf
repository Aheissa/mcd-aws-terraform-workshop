# ----------------------------------------------------------
# Multi-Region Transit Gateway Peering: US (us-east-1) and EU (eu-central-1)
# This configuration enables routing between VPCs in different AWS regions
# by creating a TGW in each region and peering them together.
#
# NOTE: EU Transit Gateway resources and routes are currently commented out.
# Only US TGW, US VPC attachment, and peering resources are active.
# If you want to enable EU TGW and routing, uncomment the relevant blocks.
# ----------------------------------------------------------

# 1. US Transit Gateway
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

# 2. EU Transit Gateway (commented out)
# resource "aws_ec2_transit_gateway" "eu" {
#   provider           = aws.eu
#   description        = "EU Transit Gateway for inter-region peering"
#   amazon_side_asn    = 64513
#   auto_accept_shared_attachments = "enable"
#   default_route_table_association = "enable"
#   default_route_table_propagation = "enable"
#   tags = {
#     Name = "eu-tgw"
#   }
# }

# 3. US VPC Attachment to US TGW
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

# 4. EU VPC Attachment to EU TGW (commented out)
# resource "aws_ec2_transit_gateway_vpc_attachment" "eu_vpc_attachment" {
#   provider           = aws.eu
#   transit_gateway_id = aws_ec2_transit_gateway.eu.id
#   vpc_id             = aws_vpc.eu_vpc.id
#   subnet_ids         = [
#     aws_subnet.eu_subnet1.id,
#     aws_subnet.eu_subnet2.id
#   ]
#   tags = {
#     Name = "eu-vpc-tgw-attachment"
#   }
# }

# 5. Peering Attachment between US and EU TGWs
# resource "aws_ec2_transit_gateway_peering_attachment" "us_eu" {
#   transit_gateway_id      = aws_ec2_transit_gateway.us.id
#   peer_transit_gateway_id = aws_ec2_transit_gateway.eu.id
#   peer_region             = "eu-central-1"
#   tags = {
#     Name = "us-eu-tgw-peering"
#   }
# }

# 6. Accept the peering attachment in the EU region
# resource "aws_ec2_transit_gateway_peering_attachment_accepter" "eu_accept" {
#   provider                        = aws.eu
#   transit_gateway_attachment_id    = aws_ec2_transit_gateway_peering_attachment.us_eu.id
#   tags = {
#     Name = "eu-accept-us-tgw-peering"
#   }
# }

# 7. US VPC Route Table: Add routes to reach EU VPC via US TGW
# resource "aws_route" "us_to_eu_z1" {
#   route_table_id         = aws_route_table.sample_route_table1.id
#   destination_cidr_block = "10.1.0.0/16" # EU VPC CIDR
#   transit_gateway_id     = aws_ec2_transit_gateway.us.id
# }
# resource "aws_route" "us_to_eu_z2" {
#   route_table_id         = aws_route_table.sample_route_table2.id
#   destination_cidr_block = "10.1.0.0/16" # EU VPC CIDR
#   transit_gateway_id     = aws_ec2_transit_gateway.us.id
# }

# 8. EU VPC Route Table: Add route to reach US VPC via EU TGW (commented out)
# resource "aws_route" "eu_to_us" {
#   provider               = aws.eu
#   route_table_id         = aws_route_table.eu_rt.id
#   destination_cidr_block = "10.0.0.0/16" # US VPC CIDR
#   transit_gateway_id     = aws_ec2_transit_gateway.eu.id
# }

# 9. US TGW Route Table: Add route to reach EU VPC via peering
# resource "aws_ec2_transit_gateway_route" "us_to_eu" {
#   transit_gateway_route_table_id = aws_ec2_transit_gateway.us.association_default_route_table_id
#   destination_cidr_block         = "10.1.0.0/16" # EU VPC CIDR
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.us_eu.id
# }

# 10. EU TGW Route Table: Add route to reach US VPC via peering (commented out)
# resource "aws_ec2_transit_gateway_route" "eu_to_us" {
#   provider                       = aws.eu
#   transit_gateway_route_table_id = aws_ec2_transit_gateway.eu.association_default_route_table_id
#   destination_cidr_block         = "10.0.0.0/16" # US VPC CIDR
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.us_eu.id
# }
