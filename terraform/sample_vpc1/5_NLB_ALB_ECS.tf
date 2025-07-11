# 5_ECS_ALB.tf
# ----------------------------------------------------------
# ECS Services (web, app, api) behind Private ALB and Public NLB for CloudFront Proxy
# ----------------------------------------------------------
# This file now includes a public NLB in front of ECS services for CloudFront integration.
# NLB forwards traffic to ECS services (Fargate) in private subnets.
# Security groups and health checks are updated for this pattern.
# ----------------------------------------------------------
# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-ecs-cluster"
}

# 2. Task Definitions (one for each service)
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.prefix}-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.spoke_iam_role.arn
  container_definitions    = jsonencode([
    {
      name      = "web"
      image     = "nginxdemos/hello:plain-text"
      portMappings = [{ containerPort = 80 }]
      environment = [
        { name = "SERVICE_NAME", value = "web" },
        { name = "REGION", value = "us-east-1" } # NOTE: Hardcoded region, update if needed
      ]
    }
  ])
}
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.prefix}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.spoke_iam_role.arn
  container_definitions    = jsonencode([
    {
      name      = "app"
      image     = "nginxdemos/hello:plain-text"
      portMappings = [{ containerPort = 80 }]
      environment = [
        { name = "SERVICE_NAME", value = "app" },
        { name = "REGION", value = "us-east-1" } # NOTE: Hardcoded region, update if needed
      ]
    }
  ])
}
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.spoke_iam_role.arn
  container_definitions    = jsonencode([
    {
      name      = "api"
      image     = "nginxdemos/hello:plain-text"
      portMappings = [{ containerPort = 80 }]
      environment = [
        { name = "SERVICE_NAME", value = "api" },
        { name = "REGION", value = "us-east-1" } # NOTE: Hardcoded region, update if needed
      ]
    }
  ])
}

# 3. Target Groups for Private ALB
resource "aws_lb_target_group" "web" {
  name     = "${var.prefix}-tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sample_vpc.id
  target_type = "ip"
  health_check {
    path = "/"
    protocol = "HTTP"
  }
}
resource "aws_lb_target_group" "app" {
  name     = "${var.prefix}-tg-app"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sample_vpc.id
  target_type = "ip"
  health_check {
    path = "/"
    protocol = "HTTP"
  }
}
resource "aws_lb_target_group" "api" {
  name     = "${var.prefix}-tg-api"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sample_vpc.id
  target_type = "ip"
  health_check {
    path = "/"
    protocol = "HTTP"
  }
}

# 4. ECS Services (one for each, in private subnets)
resource "aws_ecs_service" "web" {
  name            = "${var.prefix}-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.sample_private_subnet1.id, aws_subnet.sample_private_subnet2.id]
    security_groups  = [aws_security_group.sample_security_group.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = 80
  }
  depends_on = [aws_lb.sample_alb_private]
}
resource "aws_ecs_service" "app" {
  name            = "${var.prefix}-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.sample_private_subnet1.id, aws_subnet.sample_private_subnet2.id]
    security_groups  = [aws_security_group.sample_security_group.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }
  depends_on = [aws_lb.sample_alb_private]
}
resource "aws_ecs_service" "api" {
  name            = "${var.prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.sample_private_subnet1.id, aws_subnet.sample_private_subnet2.id]
    security_groups  = [aws_security_group.sample_security_group.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 80
  }
  depends_on = [aws_lb.sample_alb_private]
}

# 5. ALB Listener Rules for Path-based Routing
resource "aws_lb_listener_rule" "web" {
  listener_arn = aws_lb_listener.sample_alb_listener_private.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
  condition {
    path_pattern {
      values = ["/web*"]
    }
  }
  depends_on = [aws_lb_target_group.web]
}
resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.sample_alb_listener_private.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
  condition {
    path_pattern {
      values = ["/app*"]
    }
  }
  depends_on = [aws_lb_target_group.app]
}
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.sample_alb_listener_private.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    path_pattern {
      values = ["/api*"]
    }
  }
  depends_on = [aws_lb_target_group.api]
}

# ----------------------------------------------------------
# Public NLB for CloudFront Proxy
# ----------------------------------------------------------
resource "aws_lb" "public_nlb" {
  name               = "${var.prefix}-nlb-public"
  load_balancer_type = "network"
  subnets            = [aws_subnet.sample_subnet1.id, aws_subnet.sample_subnet2.id]
  internal           = false
  enable_deletion_protection = false
  tags = { Name = "${var.prefix}-nlb-public" }
}

resource "aws_lb_target_group" "nlb_ecs" {
  name        = "${var.prefix}-nlb-ecs-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.sample_vpc.id
  target_type = "ip"
  health_check {
    protocol = "TCP"
    port     = "80"
  }
  tags = { Name = "${var.prefix}-nlb-ecs-tg" }
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.public_nlb.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_ecs.arn
  }
}

resource "aws_lb_target_group_attachment" "nlb_web" {
  target_group_arn = aws_lb_target_group.nlb_ecs.arn
  target_id        = aws_ecs_service.web.network_configuration[0].assign_public_ip == false ? aws_ecs_service.web.id : null
  port             = 80
  depends_on       = [aws_ecs_service.web]
}
resource "aws_lb_target_group_attachment" "nlb_app" {
  target_group_arn = aws_lb_target_group.nlb_ecs.arn
  target_id        = aws_ecs_service.app.network_configuration[0].assign_public_ip == false ? aws_ecs_service.app.id : null
  port             = 80
  depends_on       = [aws_ecs_service.app]
}
resource "aws_lb_target_group_attachment" "nlb_api" {
  target_group_arn = aws_lb_target_group.nlb_ecs.arn
  target_id        = aws_ecs_service.api.network_configuration[0].assign_public_ip == false ? aws_ecs_service.api.id : null
  port             = 80
  depends_on       = [aws_ecs_service.api]
}
resource "aws_lb_target_group_attachment" "nlb_placeholder" {
  target_group_arn = aws_lb_target_group.nlb_ecs.arn
  target_id        = "10.0.11.10" # <-- Replace with your ALB's private IP(s) after ALB is created
  port             = 80
  # NOTE: After ALB is created, update this target_id to the ALB's private IP(s).
  # For multi-AZ, add more attachments for each ALB IP.
}
# ----------------------------------------------------------
# End of ECS + ALB/NLB path-based routing setup
# ----------------------------------------------------------
