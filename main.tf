provider "aws" {
  region = var.aws_region
}

# Create a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "main-vpc"
  }
}

# Create public subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Create private subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets_cidr)
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = element(var.private_subnets_cidr, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "main-igw"
  }
}

# Create a route table for public subnets
resource "aws_route_table" "second_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "second-route-table"
  }
}

# Associate public subnets with the route table
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_route_table.id
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "nat-eip"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "main_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets[0].id
  
  tags = {
    Name = "main-nat-gateway"
  }
  
  depends_on = [aws_internet_gateway.main_igw]
}

# Create route table for private subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main_nat.id
  }
  
  tags = {
    Name = "private-route-table"
  }
}

# Associate private subnets with the private route table
resource "aws_route_table_association" "private_subnet_association" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.private_route_table.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main_vpc.id

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
    Name = "alb-security-group"
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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
    Name = "ec2-security-group"
  }
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "application-lb"
  }
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

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
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Launch Template
resource "aws_launch_template" "app_template" {
  name_prefix   = "app-template"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Redirect output to log file and console
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              
              echo "===== STARTING USER DATA SCRIPT ====="
              echo "Hostname: $(hostname -f)"
              echo "Date: $(date)"
              
              # Test internet connectivity
              echo "===== TESTING INTERNET CONNECTIVITY ====="
              echo "Testing connection to amazon.com..."
              ping -c 2 amazon.com
              if [ $? -eq 0 ]; then
                echo "✅ Internet connectivity confirmed"
              else
                echo "❌ Internet connectivity failed"
                echo "Trying to connect to 8.8.8.8..."
                ping -c 2 8.8.8.8
              fi
              
              # Check DNS resolution
              echo "===== TESTING DNS RESOLUTION ====="
              nslookup amazon.com
              
              # Install and configure web server
              echo "===== INSTALLING AND CONFIGURING WEB SERVER ====="
              echo "Updating packages..."
              yum update -y
              if [ $? -eq 0 ]; then
                echo "✅ Package update successful"
              else
                echo "❌ Package update failed"
              fi
              
              echo "Installing Apache..."
              yum install -y httpd
              if [ $? -eq 0 ]; then
                echo "✅ Apache installation successful"
              else
                echo "❌ Apache installation failed"
              fi
              
              echo "Starting Apache..."
              systemctl start httpd
              systemctl enable httpd
              systemctl status httpd
              
              echo "Creating index page..."
              cat > /var/www/html/index.html << 'HTML'
              <!DOCTYPE html>
              <html>
              <head>
                <title>EC2 Instance Health Check</title>
                <style>
                  body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
                  h1 { color: #333; }
                  .info { background: #f4f4f4; padding: 20px; border-radius: 5px; }
                </style>
              </head>
              <body>
                <h1>Welcome to $(hostname -f)</h1>
                <div class="info">
                  <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
                  <p><strong>Availability Zone:</strong> $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
                  <p><strong>Private IP:</strong> $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)</p>
                  <p><strong>Server Time:</strong> $(date)</p>
                </div>
                <p>If you can see this page, the web server is running correctly and the instance has internet connectivity.</p>
              </body>
              </html>
              HTML
              
              echo "===== USER DATA SCRIPT COMPLETED ====="
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-server"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.alb_max_size
  min_size            = var.alb_min_size
  target_group_arns   = [aws_lb_target_group.app_tg.arn]
  vpc_zone_identifier = aws_subnet.private_subnets[*].id

  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  value       = aws_lb.app_lb.dns_name
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
