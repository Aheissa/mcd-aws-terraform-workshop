# ----------------------------------------------------------
# Sample VPC (us-east-1): VPC, Subnets, Route Tables, Security, EC2
# ----------------------------------------------------------
# This file creates a sample VPC in us-east-1 with two public subnets,
# route tables, security group, IAM role/profile, and two EC2 instances.
# Best Practice: Use one subnet per AZ for high availability.
# ----------------------------------------------------------

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
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "${var.prefix}-z1-subnet"
  }
}

resource "aws_subnet" "sample_subnet2" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.2.0/24"
  tags = {
    Name = "${var.prefix}-z2-subnet"
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
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                echo "<html><body><h1 style='font-size:48px;'>Hello World</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
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
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                echo "<html><body><h1 style='font-size:48px;'>Hello World</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
                                EOT
  subnet_id                   = aws_subnet.sample_subnet2.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z2-app"
    Category = "dev"
  }
}

# ----------------------------------------------------------
# Application Load Balancer (ALB) and Target Group
# ----------------------------------------------------------

resource "aws_lb" "sample_alb" {
  name               = "${var.prefix}-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.sample_subnet1.id, aws_subnet.sample_subnet2.id]
  security_groups    = [aws_security_group.sample_security_group.id]
  internal           = false
  enable_deletion_protection = false
  tags = {
    Name = "${var.prefix}-alb"
  }
}

resource "aws_lb_target_group" "sample_alb_tg" {
  name     = "${var.prefix}-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sample_vpc.id
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
    Name = "${var.prefix}-alb-tg"
  }
}

resource "aws_lb_listener" "sample_alb_listener" {
  load_balancer_arn = aws_lb.sample_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sample_alb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "app1_attachment" {
  target_group_arn = aws_lb_target_group.sample_alb_tg.arn
  target_id        = aws_instance.app_instance1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app2_attachment" {
  target_group_arn = aws_lb_target_group.sample_alb_tg.arn
  target_id        = aws_instance.app_instance2.id
  port             = 80
}

