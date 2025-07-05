# New VPC in eu-central-1 (Frankfurt) with 2 subnets, public ALB, and 2 ASGs

provider "aws" {
  alias  = "eu"
  region = "eu-central-1"
}

resource "aws_vpc" "eu_vpc" {
  provider   = aws.eu
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "eu-vpc"
  }
}

resource "aws_subnet" "eu_subnet1" {
  provider          = aws.eu
  vpc_id            = aws_vpc.eu_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "eu-z1-subnet"
  }
}

resource "aws_subnet" "eu_subnet2" {
  provider          = aws.eu
  vpc_id            = aws_vpc.eu_vpc.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "eu-z2-subnet"
  }
}

resource "aws_internet_gateway" "eu_igw" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu_vpc.id
  tags = {
    Name = "eu-igw"
  }
}

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

resource "aws_security_group" "eu_sg" {
  provider = aws.eu
  vpc_id   = aws_vpc.eu_vpc.id
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
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "eu-sg"
  }
}

resource "aws_instance" "eu_app_instance1" {
  provider                    = aws.eu
  ami                         = data.aws_ami.ubuntu2204.id
  instance_type               = "t2.nano"
  subnet_id                   = aws_subnet.eu_subnet1.id
  vpc_security_group_ids      = [aws_security_group.eu_sg.id]
  key_name                    = var.aws_ssh_key_pair_name
  associate_public_ip_address = true
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                echo "<html><body><h1 style='font-size:48px;'>Hello World (EU)</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
                                EOT
  tags = {
    Name = "eu-z1-app"
    Category = "prod"
  }
}

resource "aws_instance" "eu_app_instance2" {
  provider                    = aws.eu
  ami                         = data.aws_ami.ubuntu2204.id
  instance_type               = "t2.nano"
  subnet_id                   = aws_subnet.eu_subnet2.id
  vpc_security_group_ids      = [aws_security_group.eu_sg.id]
  key_name                    = var.aws_ssh_key_pair_name
  associate_public_ip_address = true
  user_data                   = <<-EOT
                                #!/bin/bash
                                apt-get update
                                apt-get install -y apache2 wget
                                HOSTNAME=$(hostname)
                                LOCALIP=$(hostname -I | awk '{print $1}')
                                AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                                echo "<html><body><h1 style='font-size:48px;'>Hello World (EU)</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
                                EOT
  tags = {
    Name = "eu-z2-app"
    Category = "dev"
  }
}

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

resource "aws_launch_template" "eu_lt" {
  provider      = aws.eu
  name_prefix   = "eu-lt-"
  image_id      = data.aws_ami.ubuntu2204.id
  instance_type = "t2.nano"
  key_name      = var.aws_ssh_key_pair_name
  vpc_security_group_ids = [aws_security_group.eu_sg.id]
  user_data = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y apache2 wget
    HOSTNAME=$(hostname)
    LOCALIP=$(hostname -I | awk '{print $1}')
    AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
    echo "<html><body><h1 style='font-size:48px;'>Hello World (EU)</h1><h2 style='font-size:36px;'>Hi! My hostname is <span style='color:blue;'>$HOSTNAME</span></h2><h2 style='font-size:36px;'>My internal IP is <span style='color:green;'>$LOCALIP</span></h2><h2 style='font-size:32px;'>Availability Zone: <span style='color:purple;'>$AZ</span></h2></body></html>" > /var/www/html/index.html
  EOT
}

resource "aws_autoscaling_group" "eu_asg1" {
  provider                = aws.eu
  name                    = "eu-asg1"
  max_size                = 2
  min_size                = 1
  desired_capacity        = 1
  vpc_zone_identifier     = [aws_subnet.eu_subnet1.id]
  launch_template {
    id      = aws_launch_template.eu_lt.id
    version = "$Latest"
  }
  target_group_arns       = [aws_lb_target_group.eu_alb_tg.arn]
  health_check_type       = "ELB"
  health_check_grace_period = 120
  tag {
    key                 = "Name"
    value               = "eu-asg1-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "eu_asg2" {
  provider                = aws.eu
  name                    = "eu-asg2"
  max_size                = 2
  min_size                = 1
  desired_capacity        = 1
  vpc_zone_identifier     = [aws_subnet.eu_subnet2.id]
  launch_template {
    id      = aws_launch_template.eu_lt.id
    version = "$Latest"
  }
  target_group_arns       = [aws_lb_target_group.eu_alb_tg.arn]
  health_check_type       = "ELB"
  health_check_grace_period = 120
  tag {
    key                 = "Name"
    value               = "eu-asg2-instance"
    propagate_at_launch = true
  }
}
