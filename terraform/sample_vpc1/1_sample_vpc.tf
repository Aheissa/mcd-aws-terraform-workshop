data "aws_ami" "ubuntu2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "sample_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.prefix}-vpc"
  }
}

resource "aws_internet_gateway" "sample_internet_gateway" {
  tags = {
    Name = "${var.prefix}-igw"
  }
}

resource "aws_internet_gateway_attachment" "sample_igw_attachment" {
  internet_gateway_id = aws_internet_gateway.sample_internet_gateway.id
  vpc_id              = aws_vpc.sample_vpc.id
}

resource "aws_subnet" "sample_subnet1" {
  availability_zone = var.aws_availability_zone1
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.0.0/24"
  tags = {
    Name = "${var.prefix}-z1-subnet"
  }
}

resource "aws_subnet" "sample_subnet2" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.3.0/24"
  tags = {
    Name = "${var.prefix}-z2-subnet"
  }
}

# --- Add second subnet in AZ1 ---
resource "aws_subnet" "sample_subnet1b" {
  availability_zone = var.aws_availability_zone1
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "${var.prefix}-z1-subnet-b"
  }
}

# --- Add second subnet in AZ2 ---
resource "aws_subnet" "sample_subnet2b" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.4.0/24"
  tags = {
    Name = "${var.prefix}-z2-subnet-b"
  }
}

resource "aws_route_table" "sample_route_table1" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = {
    Name = "${var.prefix}-z1-rt"
  }
}

resource "aws_route_table" "sample_route_table2" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = {
    Name = "${var.prefix}-z2-rt"
  }
}

# --- Add route tables for new subnets ---
resource "aws_route_table" "sample_route_table1b" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = {
    Name = "${var.prefix}-z1-rt-b"
  }
}

resource "aws_route_table" "sample_route_table2b" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = {
    Name = "${var.prefix}-z2-rt-b"
  }
}

# --- Step 6: Secure VPC --- Disable the following two routes (towards internet gateway)
resource "aws_route" "sample_internet_route1" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample_internet_gateway.id
  route_table_id         = aws_route_table.sample_route_table1.id
}

resource "aws_route" "sample_internet_route2" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample_internet_gateway.id
  route_table_id         = aws_route_table.sample_route_table2.id
}

resource "aws_route" "sample_internet_route1b" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample_internet_gateway.id
  route_table_id         = aws_route_table.sample_route_table1b.id
}

resource "aws_route" "sample_internet_route2b" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample_internet_gateway.id
  route_table_id         = aws_route_table.sample_route_table2b.id
}

# --- Step 6: Secure VPC --- Enable the following two routes (towards MCD transit gateway)
# resource "aws_route" "sample_internet_route1" {
#   destination_cidr_block = "0.0.0.0/0"
#   transit_gateway_id     = var.mcd_transit_gateway_id
#   route_table_id         = aws_route_table.sample_route_table1.id
#   depends_on = [
#     ciscomcd_spoke_vpc.mcd_spoke
#   ]
# }

# resource "aws_route" "sample_internet_route2" {
#   destination_cidr_block = "0.0.0.0/0"
#   transit_gateway_id     = var.mcd_transit_gateway_id
#   route_table_id         = aws_route_table.sample_route_table2.id
#   depends_on = [
#     ciscomcd_spoke_vpc.mcd_spoke
#   ]
# }

resource "aws_route_table_association" "sample_subnet_route_table_association1" {
  route_table_id = aws_route_table.sample_route_table1.id
  subnet_id      = aws_subnet.sample_subnet1.id
}

resource "aws_route_table_association" "sample_subnet_route_table_association2" {
  route_table_id = aws_route_table.sample_route_table2.id
  subnet_id      = aws_subnet.sample_subnet2.id
}

resource "aws_route_table_association" "sample_subnet_route_table_association1b" {
  route_table_id = aws_route_table.sample_route_table1b.id
  subnet_id      = aws_subnet.sample_subnet1b.id
}

resource "aws_route_table_association" "sample_subnet_route_table_association2b" {
  route_table_id = aws_route_table.sample_route_table2b.id
  subnet_id      = aws_subnet.sample_subnet2b.id
}

resource "aws_security_group" "sample_security_group" {
  name   = "${var.prefix}-security-group"
  vpc_id = aws_vpc.sample_vpc.id
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8000
    to_port     = 8000
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-security-group"
  }
}

resource "aws_iam_role" "spoke_iam_role" {
  name = "${var.prefix}-spoke-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  path = "/"
  inline_policy {
    name = "spoke-iam-policy"
    policy = jsonencode(
      {
        Version = "2012-10-17",
        Statement = [
          {
            Action   = "*"
            Resource = "*"
            Effect   = "Allow"
          }
        ]
      }
    )
  }
}

resource "aws_iam_instance_profile" "spoke_instance_profile" {
  name = aws_iam_role.spoke_iam_role.name
  path = "/"
  role = aws_iam_role.spoke_iam_role.name
}

resource "aws_instance" "app_instance1" {
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone1
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get upgrade -y
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                echo "<html><body><h1>Hello World</h1><p>Hi my hostname is $HOSTNAME and my internal IP is $LOCALIP</p></body></html>" > /var/www/html/index.html
  EOT
  subnet_id                   = aws_subnet.sample_subnet1.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z1-app"
    Category = "prod"
  }
}

resource "aws_instance" "app_instance2" {
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone2
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get upgrade -y
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                echo "<html><body><h1>Hello World</h1><p>Hi my hostname is $HOSTNAME and my internal IP is $LOCALIP</p></body></html>" > /var/www/html/index.html
  EOT
  subnet_id                   = aws_subnet.sample_subnet2.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z2-app"
    Category = "dev"
  }
}

resource "aws_instance" "app_instance1b" {
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone1
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get upgrade -y
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                echo "<html><body><h1>Hello World</h1><p>Hi my hostname is $HOSTNAME and my internal IP is $LOCALIP</p></body></html>" > /var/www/html/index.html
  EOT
  subnet_id                   = aws_subnet.sample_subnet1b.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z1b-app"
    Category = "prod"
  }
}

resource "aws_instance" "app_instance2b" {
  associate_public_ip_address = true
  availability_zone           = var.aws_availability_zone2
  ami                         = data.aws_ami.ubuntu2204.id
  iam_instance_profile        = aws_iam_instance_profile.spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get upgrade -y
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                echo "<html><body><h1>Hello World</h1><p>Hi my hostname is $HOSTNAME and my internal IP is $LOCALIP</p></body></html>" > /var/www/html/index.html
  EOT
  subnet_id                   = aws_subnet.sample_subnet2b.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z2b-app"
    Category = "dev"
  }
}

