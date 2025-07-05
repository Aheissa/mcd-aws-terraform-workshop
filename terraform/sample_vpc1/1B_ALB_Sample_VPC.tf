# Public Application Load Balancer for sample VPC

resource "aws_security_group" "alb_sg" {
  name        = "${var.prefix}-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = aws_vpc.sample_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-alb-sg"
  }
}

resource "aws_lb" "sample_alb" {
  name               = "${var.prefix}-alb"
  load_balancer_type = "application"
  subnets = [
    aws_subnet.sample_subnet1.id,
    aws_subnet.sample_subnet1b.id,
    aws_subnet.sample_subnet2.id,
    aws_subnet.sample_subnet2b.id
  ]
  security_groups    = [aws_security_group.alb_sg.id]
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

resource "aws_lb_target_group_attachment" "app1b_attachment" {
  target_group_arn = aws_lb_target_group.sample_alb_tg.arn
  target_id        = aws_instance.app_instance1b.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app2b_attachment" {
  target_group_arn = aws_lb_target_group.sample_alb_tg.arn
  target_id        = aws_instance.app_instance2b.id
  port             = 80
}
