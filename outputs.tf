output "vpc" {
  description = "Values of the VPC created"
  value = {
    id         = aws_vpc.main_vpc.id
    cidr_block = aws_vpc.main_vpc.cidr_block
    tags       = aws_vpc.main_vpc.tags
  }
}

output "public_subnets" {
  description = "Details of public subnets created"
  value = [
    for subnet in aws_subnet.public_subnets : {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      tags             = subnet.tags
    }
  ]
}

output "private_subnets" {
  description = "Details of private subnets created"
  value = [
    for subnet in aws_subnet.private_subnets : {
      id                = subnet.id
      cidr_block        = subnet.cidr_block
      availability_zone = subnet.availability_zone
      tags             = subnet.tags
    }
  ]
}

output "internet_gateway" {
  description = "Details of the Internet Gateway"
  value = {
    id   = aws_internet_gateway.main_igw.id
    tags = aws_internet_gateway.main_igw.tags
  }
}

output "route_tables" {
  description = "Details of route tables"
  value = {
    public = {
      id    = aws_route_table.second_route_table.id
      routes = aws_route_table.second_route_table.route
      tags   = aws_route_table.second_route_table.tags
    }
  }
}

output "security_groups" {
  description = "Details of security groups"
  value = {
    alb = {
      id          = aws_security_group.alb_sg.id
      name        = aws_security_group.alb_sg.name
      description = aws_security_group.alb_sg.description
      tags        = aws_security_group.alb_sg.tags
    }
    ec2 = {
      id          = aws_security_group.ec2_sg.id
      name        = aws_security_group.ec2_sg.name
      description = aws_security_group.ec2_sg.description
      tags        = aws_security_group.ec2_sg.tags
    }
  }
}

output "load_balancer" {
  description = "Details of the Application Load Balancer"
  value = {
    id                = aws_lb.app_lb.id
    arn              = aws_lb.app_lb.arn
    dns_name         = aws_lb.app_lb.dns_name
    zone_id          = aws_lb.app_lb.zone_id
    security_groups  = aws_lb.app_lb.security_groups
    subnets         = aws_lb.app_lb.subnets
    tags            = aws_lb.app_lb.tags
  }
}

output "target_group" {
  description = "Details of the ALB Target Group"
  value = {
    id                = aws_lb_target_group.app_tg.id
    arn              = aws_lb_target_group.app_tg.arn
    name             = aws_lb_target_group.app_tg.name
    port             = aws_lb_target_group.app_tg.port
    protocol         = aws_lb_target_group.app_tg.protocol
    vpc_id           = aws_lb_target_group.app_tg.vpc_id
    health_check     = aws_lb_target_group.app_tg.health_check
  }
}

output "launch_template" {
  description = "Details of the Launch Template"
  value = {
    id                = aws_launch_template.app_template.id
    arn              = aws_launch_template.app_template.arn
    name             = aws_launch_template.app_template.name
    latest_version   = aws_launch_template.app_template.latest_version
    tags_all         = aws_launch_template.app_template.tags_all
  }
}

output "autoscaling_group" {
  description = "Details of the Auto Scaling Group"
  value = {
    id                    = aws_autoscaling_group.app_asg.id
    arn                   = aws_autoscaling_group.app_asg.arn
    name                  = aws_autoscaling_group.app_asg.name
    desired_capacity      = aws_autoscaling_group.app_asg.desired_capacity
    max_size             = aws_autoscaling_group.app_asg.max_size
    min_size             = aws_autoscaling_group.app_asg.min_size
    target_group_arns    = aws_autoscaling_group.app_asg.target_group_arns
    vpc_zone_identifier  = aws_autoscaling_group.app_asg.vpc_zone_identifier
  }
}

output "availability_zones" {
  description = "List of Availability Zones being used"
  value = var.azs
}

output "application_endpoint" {
  description = "The endpoint URL to access the web application"
  value = format("http://%s", aws_lb.app_lb.dns_name)
}