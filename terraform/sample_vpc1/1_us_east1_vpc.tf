# ----------------------------------------------------------
# Sample VPC (us-east-1): VPC, Subnets, Route Tables, Security, IAM, EC2, ALBs
# ----------------------------------------------------------
# This file creates a sample VPC in us-east-1 with two public subnets,
# route tables, security group, IAM role/profile, and two EC2 instances.
# Best Practice: Use one subnet per AZ for high availability.
# ----------------------------------------------------------

# 1. Data Sources
# ----------------------------------------------------------
# Get latest Ubuntu 22.04 AMI for us-east-1
# Canonical official AMI
# Used for EC2 instances
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

# 2. Networking: VPC, IGW, Subnets, Route Tables
# ----------------------------------------------------------
# Create VPC
# ----------------------------------------------------------
resource "aws_vpc" "sample_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "${var.prefix}-vpc" }
}

# Create Internet Gateway for VPC
# ----------------------------------------------------------
resource "aws_internet_gateway" "sample_internet_gateway" {
  tags = { Name = "${var.prefix}-igw" }
}

# Attach Internet Gateway to VPC
# ----------------------------------------------------------
resource "aws_internet_gateway_attachment" "sample_igw_attachment" {
  internet_gateway_id = aws_internet_gateway.sample_internet_gateway.id
  vpc_id              = aws_vpc.sample_vpc.id
}

# Public Subnets (renamed)
# ----------------------------------------------------------
resource "aws_subnet" "sample_subnet1" {
  availability_zone = var.aws_availability_zone1
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.1.0/24"
  tags = { Name = "${var.prefix}-z1-public-subnet" }
}
resource "aws_subnet" "sample_subnet2" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.2.0/24"
  tags = { Name = "${var.prefix}-z2-public-subnet" }
}

# Private Subnets
# ----------------------------------------------------------
resource "aws_subnet" "sample_private_subnet1" {
  availability_zone = var.aws_availability_zone1
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.11.0/24"
  tags = { Name = "${var.prefix}-z1-private-subnet" }
}
resource "aws_subnet" "sample_private_subnet2" {
  availability_zone = var.aws_availability_zone2
  vpc_id            = aws_vpc.sample_vpc.id
  cidr_block        = "10.0.12.0/24"
  tags = { Name = "${var.prefix}-z2-private-subnet" }
}

# Public Route Table (combined)
# ----------------------------------------------------------
resource "aws_route_table" "sample_public_rt" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = { Name = "${var.prefix}-public-rt" }
}
resource "aws_route" "sample_public_internet_route" {
  route_table_id         = aws_route_table.sample_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.sample_internet_gateway.id
}
resource "aws_route_table_association" "sample_subnet1_public_rt" {
  route_table_id = aws_route_table.sample_public_rt.id
  subnet_id      = aws_subnet.sample_subnet1.id
}
resource "aws_route_table_association" "sample_subnet2_public_rt" {
  route_table_id = aws_route_table.sample_public_rt.id
  subnet_id      = aws_subnet.sample_subnet2.id
}

# Private Route Table
# ----------------------------------------------------------
resource "aws_route_table" "sample_private_rt" {
  vpc_id = aws_vpc.sample_vpc.id
  tags = { Name = "${var.prefix}-private-rt" }
}
resource "aws_route_table_association" "sample_private_subnet1_private_rt" {
  route_table_id = aws_route_table.sample_private_rt.id
  subnet_id      = aws_subnet.sample_private_subnet1.id
}
resource "aws_route_table_association" "sample_private_subnet2_private_rt" {
  route_table_id = aws_route_table.sample_private_rt.id
  subnet_id      = aws_subnet.sample_private_subnet2.id
}

# 3. Security
# ----------------------------------------------------------
# Security group for EC2 and ALB
# Allows HTTP, HTTPS, port 8000, and all egress
# ----------------------------------------------------------
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
  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.prefix}-security-group" }
}

# 4. IAM
# ----------------------------------------------------------
# IAM role and instance profile for EC2
# ----------------------------------------------------------
resource "aws_iam_role" "spoke_iam_role" {
  name = "${var.prefix}-spoke-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  path = "/"
}

resource "aws_iam_role_policy" "spoke_iam_policy" {
  name = "spoke-iam-policy"
  role = aws_iam_role.spoke_iam_role.id
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

resource "aws_iam_instance_profile" "spoke_instance_profile" {
  name = aws_iam_role.spoke_iam_role.name
  path = "/"
  role = aws_iam_role.spoke_iam_role.name
}

# 5. EC2 Instances
# ----------------------------------------------------------
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
                                mkdir -p /var/www/html/alb
                                FQDN=$(hostname -f)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                PUBLICIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                cat <<EOF > /var/www/html/index.html
<html>
  <body style="background: #f4f4f4; font-family: Arial, sans-serif;">
    <h1 style="color: #2e86de; font-size: 48px; font-family: 'Trebuchet MS', sans-serif;">Hello from EC2! Root Directory /</h1>
    <p style="font-size: 22px; color: #333;">FQDN: <span style="color: #8e44ad;"><b>$FQDN</b></span></p>
    <p style="font-size: 22px; color: #333;">Internal IP: <span style="color: #d35400;"><b>$LOCALIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Public IP: <span style="color: #c0392b;"><b>$PUBLICIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Availability Zone: <span style="color: #16a085;"><b>$AZ</b></span></p>
    <hr>
    <h2 style="color: #e74c3c; font-size: 30px;">Free Palestine 🇵🇸</h2>
  </body>
</html>
EOF
                                cat <<EOF > /var/www/html/alb/index.html
<html>
  <body style="background: #f4f4f4; font-family: Arial, sans-serif;">
    <h1 style="color: #2e86de; font-size: 48px; font-family: 'Trebuchet MS', sans-serif;">Hello from EC2! ALB Directory /alb</h1>
    <p style="font-size: 22px; color: #333;">FQDN: <span style="color: #8e44ad;"><b>$FQDN</b></span></p>
    <p style="font-size: 22px; color: #333;">Internal IP: <span style="color: #d35400;"><b>$LOCALIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Public IP: <span style="color: #c0392b;"><b>$PUBLICIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Availability Zone: <span style="color: #16a085;"><b>$AZ</b></span></p>
    <hr>
    <h2 style="color: #27ae60; font-size: 30px;">Free Palestine 🇵🇸</h2>
  </body>
</html>
EOF
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
                                mkdir -p /var/www/html/alb
                                FQDN=$(hostname -f)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                PUBLICIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                cat <<EOF > /var/www/html/index.html
<html>
  <body style="background: #f4f4f4; font-family: Arial, sans-serif;">
    <h1 style="color: #2e86de; font-size: 48px; font-family: 'Trebuchet MS', sans-serif;">Hello from EC2! Root Directory /</h1>
    <p style="font-size: 22px; color: #333;">FQDN: <span style="color: #8e44ad;"><b>$FQDN</b></span></p>
    <p style="font-size: 22px; color: #333;">Internal IP: <span style="color: #d35400;"><b>$LOCALIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Public IP: <span style="color: #c0392b;"><b>$PUBLICIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Availability Zone: <span style="color: #16a085;"><b>$AZ</b></span></p>
    <hr>
    <h2 style="color: #e74c3c; font-size: 30px;">Free Palestine 🇵🇸</h2>
  </body>
</html>
EOF
                                cat <<EOF > /var/www/html/alb/index.html
<html>
  <body style="background: #f4f4f4; font-family: Arial, sans-serif;">
    <h1 style="color: #2e86de; font-size: 48px; font-family: 'Trebuchet MS', sans-serif;">Hello from EC2! ALB Directory /alb</h1>
    <p style="font-size: 22px; color: #333;">FQDN: <span style="color: #8e44ad;"><b>$FQDN</b></span></p>
    <p style="font-size: 22px; color: #333;">Internal IP: <span style="color: #d35400;"><b>$LOCALIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Public IP: <span style="color: #c0392b;"><b>$PUBLICIP</b></span></p>
    <p style="font-size: 22px; color: #333;">Availability Zone: <span style="color: #16a085;"><b>$AZ</b></span></p>
    <hr>
    <h2 style="color: #27ae60; font-size: 30px;">Free Palestine 🇵🇸</h2>
  </body>
</html>
EOF
  EOT
  subnet_id                   = aws_subnet.sample_subnet2.id
  vpc_security_group_ids      = [aws_security_group.sample_security_group.id]
  tags = {
    Name = "${var.prefix}-z2-app"
    Category = "dev"
  }
}

# 6. Application Load Balancers (Public & Private)
# ----------------------------------------------------------
resource "aws_lb" "sample_alb_public" {
  name               = "${var.prefix}-alb-public"
  load_balancer_type = "application"
  subnets            = [aws_subnet.sample_subnet1.id, aws_subnet.sample_subnet2.id]
  security_groups    = [aws_security_group.sample_security_group.id]
  internal           = false
  enable_deletion_protection = false
  tags = { Name = "${var.prefix}-alb-public" }
}
resource "aws_lb_target_group" "sample_alb_tg_public" {
  name     = "${var.prefix}-alb-tg-public"
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
  tags = { Name = "${var.prefix}-alb-tg-public" }
}
resource "aws_lb_listener" "sample_alb_listener_public" {
  load_balancer_arn = aws_lb.sample_alb_public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sample_alb_tg_public.arn
  }
}
resource "aws_lb_target_group_attachment" "app1_attachment_public" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_public.arn
  target_id        = aws_instance.app_instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "app2_attachment_public" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_public.arn
  target_id        = aws_instance.app_instance2.id
  port             = 80
}
resource "aws_lb" "sample_alb_private" {
  name               = "${var.prefix}-alb-private"
  load_balancer_type = "application"
  subnets            = [aws_subnet.sample_private_subnet1.id, aws_subnet.sample_private_subnet2.id]
  security_groups    = [aws_security_group.sample_security_group.id]
  internal           = true
  enable_deletion_protection = false
  tags = { Name = "${var.prefix}-alb-private" }
}
resource "aws_lb_target_group" "sample_alb_tg_private" {
  name     = "${var.prefix}-alb-tg-private"
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
  tags = { Name = "${var.prefix}-alb-tg-private" }
}
resource "aws_lb_listener" "sample_alb_listener_private" {
  load_balancer_arn = aws_lb.sample_alb_private.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sample_alb_tg_private.arn
  }
}
resource "aws_lb_target_group_attachment" "app1_attachment_private" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_private.arn
  target_id        = aws_instance.app_instance1.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "app2_attachment_private" {
  target_group_arn = aws_lb_target_group.sample_alb_tg_private.arn
  target_id        = aws_instance.app_instance2.id
  port             = 80
}
# ----------------------------------------------------------
# End of US VPC resources
# ----------------------------------------------------------

