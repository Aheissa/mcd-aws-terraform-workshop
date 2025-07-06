# ----------------------------------------------------------
# Sample VPC (eu-central-1): VPC, Subnets, Route Tables, Security, EC2
# ----------------------------------------------------------
# This file creates a sample VPC in eu-central-1 with two public subnets,
# route tables, security group, IAM role/profile, and two EC2 instances.
# Best Practice: Use one subnet per AZ for high availability.
# ----------------------------------------------------------

# Provider for EU region
provider "aws" {
  alias  = "eu"
  region = "eu-central-1"
}

# Get latest Ubuntu 22.04 AMI for eu-central-1
# Canonical official AMI
# Used for EC2 instances
# ----------------------------------------------------------
data "aws_ami" "ubuntu2204_eu" {
  provider    = aws.eu
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

# Create VPC
# ----------------------------------------------------------
resource "aws_vpc" "eu_vpc" {
  provider   = aws.eu
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "${var.prefix}-eu-vpc"
  }
}

# Create Internet Gateway for VPC
# ----------------------------------------------------------
resource "aws_internet_gateway" "eu_igw" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu_vpc.id
  tags = {
    Name = "eu-igw"
  }
}

# Attach public subnets in two AZs
# ----------------------------------------------------------
resource "aws_subnet" "eu_subnet1" {
  provider          = aws.eu
  vpc_id            = aws_vpc.eu_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "${var.prefix}-eu-z1-subnet"
  }
}

resource "aws_subnet" "eu_subnet2" {
  provider          = aws.eu
  vpc_id            = aws_vpc.eu_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "${var.prefix}-eu-z2-subnet"
  }
}

# Create route table for public subnets
# ----------------------------------------------------------
resource "aws_route_table" "eu_rt" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eu_igw.id
  }
  tags = {
    Name = "eu-rt"
  }
}

# Associate subnets with route table
# ----------------------------------------------------------
resource "aws_route_table_association" "eu_rta1" {
  provider      = aws.eu
  subnet_id     = aws_subnet.eu_subnet1.id
  route_table_id = aws_route_table.eu_rt.id
}

resource "aws_route_table_association" "eu_rta2" {
  provider      = aws.eu
  subnet_id     = aws_subnet.eu_subnet2.id
  route_table_id = aws_route_table.eu_rt.id
}

# Security group for EC2 and ALB
# Allows HTTP, HTTPS, and all egress
# ----------------------------------------------------------
resource "aws_security_group" "eu_sg" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu_vpc.id
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
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.prefix}-eu-sg"
  }
}

# IAM role and instance profile for EC2
# ----------------------------------------------------------
resource "aws_iam_role" "eu_spoke_iam_role" {
  provider = aws.eu
  name = "eu-spoke-role"
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
    name = "eu-spoke-iam-policy"
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Action   = "*"
          Resource = "*"
          Effect   = "Allow"
        }
      ]
    })
  }
}

resource "aws_iam_instance_profile" "eu_spoke_instance_profile" {
  provider = aws.eu
  name = aws_iam_role.eu_spoke_iam_role.name
  path = "/"
  role = aws_iam_role.eu_spoke_iam_role.name
}

# EC2 instances in each subnet
# ----------------------------------------------------------
resource "aws_instance" "eu_app_instance1" {
  provider                    = aws.eu
  availability_zone           = "eu-central-1a"
  ami                         = data.aws_ami.ubuntu2204_eu.id
  iam_instance_profile        = aws_iam_instance_profile.eu_spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                echo "<html><body><h1 style='font-size:48px;'>Hello World (EU)</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
                                EOT
  subnet_id                   = aws_subnet.eu_subnet1.id
  vpc_security_group_ids      = [aws_security_group.eu_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "${var.prefix}-eu-z1-app"
    Category = "prod"
  }
}

resource "aws_instance" "eu_app_instance2" {
  provider                    = aws.eu
  availability_zone           = "eu-central-1b"
  ami                         = data.aws_ami.ubuntu2204_eu.id
  iam_instance_profile        = aws_iam_instance_profile.eu_spoke_instance_profile.name
  instance_type               = "t2.nano"
  key_name                    = var.aws_ssh_key_pair_name
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                echo "<html><body><h1 style='font-size:48px;'>Hello World (EU)</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
                                EOT
  subnet_id                   = aws_subnet.eu_subnet2.id
  vpc_security_group_ids      = [aws_security_group.eu_sg.id]
  associate_public_ip_address = true
  tags = {
    Name = "${var.prefix}-eu-z2-app"
    Category = "dev"
  }
}

# Application Load Balancer (ALB) and Target Group
# ----------------------------------------------------------
resource "aws_lb" "eu_alb" {
  provider           = aws.eu
  name               = "eu-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.eu_subnet1.id, aws_subnet.eu_subnet2.id]
  security_groups    = [aws_security_group.eu_sg.id]
  internal           = false
  enable_deletion_protection = false
  tags = {
    Name = "eu-alb"
  }
}

resource "aws_lb_target_group" "eu_alb_tg" {
  provider = aws.eu
  name     = "eu-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.eu_vpc.id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "eu-alb-tg"
  }
}

resource "aws_lb_listener" "eu_alb_listener" {
  provider          = aws.eu
  load_balancer_arn = aws_lb.eu_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eu_alb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "eu_app1_attachment" {
  provider          = aws.eu
  target_group_arn  = aws_lb_target_group.eu_alb_tg.arn
  target_id         = aws_instance.eu_app_instance1.id
  port              = 80
}

resource "aws_lb_target_group_attachment" "eu_app2_attachment" {
  provider          = aws.eu
  target_group_arn  = aws_lb_target_group.eu_alb_tg.arn
  target_id         = aws_instance.eu_app_instance2.id
  port              = 80
}
# ----------------------------------------------------------
# End of EU VPC resources
# ----------------------------------------------------------
