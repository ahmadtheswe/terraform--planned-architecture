provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "backend_app_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "backend-app-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "backend_app_public_subnets" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.backend_app_vpc.id
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "backend-app-public-subnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "backend_app_private_subnets" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.backend_app_vpc.id
  cidr_block        = element(var.private_subnets_cidr, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "backend-app-private-subnet-${count.index + 1}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "backend_app_igw" {
  vpc_id = aws_vpc.backend_app_vpc.id

  tags = {
    Name = "backend-app-igw"
  }
}

# Create a route table for public subnets
resource "aws_route_table" "backend_app_public_route_table" {
  vpc_id = aws_vpc.backend_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.backend_app_igw.id
  }

  tags = {
    Name = "backend-app-public-route-table"
  }
}

# Associate public subnets with the route table
resource "aws_route_table_association" "backend_app_public_subnet_association" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.backend_app_public_subnets[*].id, count.index)
  route_table_id = aws_route_table.backend_app_public_route_table.id
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "backend_app_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "backend-app-nat-eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "backend_app_nat_gateway" {
  allocation_id = aws_eip.backend_app_nat_eip.id
  subnet_id     = aws_subnet.backend_app_public_subnets[0].id
  connectivity_type = "public"

  tags = {
    Name = "backend-app-nat-gateway"
  }

  depends_on = [aws_internet_gateway.backend_app_igw]
}

# Modify the default route table for private subnets
resource "aws_default_route_table" "backend_app_default_rt" {
  default_route_table_id = aws_vpc.backend_app_vpc.default_route_table_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.backend_app_nat_gateway.id
  }

  tags = {
    Name = "backend-app-default-route-table"
  }
}

# No explicit associations needed - private subnets will use the default route table
# Comment out or remove the explicit associations
# resource "aws_route_table_association" "backend_app_private_subnet_association" {
#   count          = length(var.private_subnets_cidr)
#   subnet_id      = element(aws_subnet.backend_app_private_subnets[*].id, count.index)
#   route_table_id = aws_route_table.backend_app_private_route_table.id
# }

# Security Group for ALB
resource "aws_security_group" "backend_app_alb_sg" {
  name        = "backend-app-alb-security-group"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.backend_app_vpc.id

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
    Name = "backend-app-alb-security-group"
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "backend_app_ec2_sg" {
  name        = "backend-app-ec2-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.backend_app_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_app_alb_sg.id]
    description     = "Allow HTTP traffic from ALB"
  }

  # Add explicit health check ingress rule
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ALB health checks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-app-ec2-security-group"
  }
}

# Application Load Balancer
resource "aws_lb" "backend_app_lb" {
  name               = "backend-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_app_alb_sg.id]
  subnets            = aws_subnet.backend_app_public_subnets[*].id

  tags = {
    Name = "backend-app-lb"
  }
}

# Target Group
resource "aws_lb_target_group" "backend_app_tg" {
  name     = "backend-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.backend_app_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 60
    timeout             = 10
    path                = "/"
    port                = "traffic-port"
    unhealthy_threshold = 3
    matcher             = "200-299"
  }
}

# Listener
resource "aws_lb_listener" "backend_app_listener" {
  load_balancer_arn = aws_lb.backend_app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_app_tg.arn
  }
}

# Launch Template
resource "aws_launch_template" "backend_app_template" {
  name_prefix   = "backend-app-template"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.backend_app_ec2_sg.id]

  # user_data = base64encode(<<-EOF
  #             #!/bin/bash
  #             # Update all installed packages
  #             sudo yum update -y

  #             # Install Apache HTTP Server
  #             sudo yum install -y httpd

  #             # Start the Apache service
  #             sudo systemctl start httpd

  #             # Enable Apache to start on boot
  #             sudo systemctl enable httpd

  #             # Get the instance's hostname
  #             HOSTNAME=$(hostname)

  #             # Create a simple index.html file with the hostname
  #             echo "<h1>Hello from EC2 instance: $HOSTNAME</h1>" | sudo tee /var/www/html/index.html
  #             EOF
  # )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "backend-app-server"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "backend_app_asg" {
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.alb_max_size
  min_size            = var.alb_min_size
  target_group_arns   = [aws_lb_target_group.backend_app_tg.arn]
  vpc_zone_identifier = aws_subnet.backend_app_private_subnets[*].id

  launch_template {
    id      = aws_launch_template.backend_app_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "backend-app-server"
    propagate_at_launch = true
  }
}

# Output ALB DNS name
output "backend_app_lb_dns_name" {
  value       = aws_lb.backend_app_lb.dns_name
  description = "The DNS name of the Application Load Balancer"
}

# # VPC Link for API Gateway
# resource "aws_apigatewayv2_vpc_link" "example" {
#   name               = "example-vpc-link"
#   security_group_ids = [aws_security_group.alb_sg.id]
#   subnet_ids         = aws_subnet.public_subnets[*].id
# }

# # HTTP API Gateway
# resource "aws_apigatewayv2_api" "example" {
#   name          = "example-http-api"
#   protocol_type = "HTTP"
# }

# # API Gateway Stage
# resource "aws_apigatewayv2_stage" "example" {
#   api_id      = aws_apigatewayv2_api.example.id
#   name        = "$default"
#   auto_deploy = true
# }

# # API Gateway Integration
# resource "aws_apigatewayv2_integration" "example" {
#   api_id           = aws_apigatewayv2_api.example.id
#   integration_type = "HTTP_PROXY"
#   integration_uri  = aws_lb_listener.front_end.arn

#   integration_method = "ANY"
#   connection_type    = "VPC_LINK"
#   connection_id      = aws_apigatewayv2_vpc_link.example.id
# }

# # API Gateway Route
# resource "aws_apigatewayv2_route" "example" {
#   api_id    = aws_apigatewayv2_api.example.id
#   route_key = "ANY /{proxy+}"
#   target    = "integrations/${aws_apigatewayv2_integration.example.id}"
# }

# # Output the API Gateway URL
# output "api_gateway_url" {
#   value = aws_apigatewayv2_stage.example.invoke_url
#   description = "The URL to invoke the API Gateway endpoint"
# }
