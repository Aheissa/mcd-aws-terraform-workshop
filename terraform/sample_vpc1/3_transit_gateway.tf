# ----------------------------------------------------------
# Transit Gateway and Attachments for US and EU VPCs
# ----------------------------------------------------------

# Create the Transit Gateway (TGW) in the default provider region (us-east-1)
resource "aws_ec2_transit_gateway" "main" {
  description         = "Main Transit Gateway for US and EU VPCs"
  amazon_side_asn     = 64512
  auto_accept_shared_attachments = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = {
    Name = "main-tgw"
  }
}

# Attach the US VPC to the Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "us_vpc_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.sample_vpc.id
  subnet_ids         = [
    aws_subnet.sample_subnet1.id,
    aws_subnet.sample_subnet2.id
  ]
  tags = {
    Name = "us-vpc-tgw-attachment"
  }
}

# Attach the EU VPC to the Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "eu_vpc_attachment" {
  provider           = aws.eu
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.eu_vpc.id
  subnet_ids         = [
    aws_subnet.eu_subnet1.id,
    aws_subnet.eu_subnet2.id
  ]
  tags = {
    Name = "eu-vpc-tgw-attachment"
  }
}

# Add route in US VPC route tables to reach EU VPC via TGW
resource "aws_route" "us_to_eu_z1" {
  route_table_id         = aws_route_table.sample_route_table1.id
  destination_cidr_block = "10.1.0.0/16" # EU VPC CIDR
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "us_to_eu_z2" {
  route_table_id         = aws_route_table.sample_route_table2.id
  destination_cidr_block = "10.1.0.0/16" # EU VPC CIDR
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

# Add route in EU VPC route table to reach US VPC via TGW
resource "aws_route" "eu_to_us" {
  provider               = aws.eu
  route_table_id         = aws_route_table.eu_rt.id
  destination_cidr_block = "10.0.0.0/16" # US VPC CIDR
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

# ----------------------------------------------------------
# NOTES:
# - Only one TGW is needed per region/account.
# - Each VPC attachment requires one subnet per AZ (not every subnet).
# - After creating attachments, update VPC route tables to route inter-VPC traffic via the TGW.
# - If VPCs are in different accounts, additional steps are needed (resource sharing, acceptance).
# ----------------------------------------------------------
