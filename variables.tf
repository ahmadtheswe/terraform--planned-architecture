variable "aws_region" {
  type        = string
  description = "AWS region where resources will be created"
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  type        = list(string)
  description = "Public subnet CIDR values"
  # default     = [ "10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24" ]
  default     = [ "10.0.1.0/24", "10.0.2.0/24" ]
}

variable "private_subnets_cidr" {
  type        = list(string)
  description = "Private subnet CIDR values"
  # default     = [ "10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24" ]
  default     = [ "10.0.4.0/24", "10.0.5.0/24" ]
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones to use for the subnets"
  # default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2 instances (Amazon Linux 2 in ap-southeast-1)"
  default     = "ami-0f74c08b8b5effa56"
}

variable "asg_desired_capacity" {
  type        = number
  description = "Desired capacity for the Auto Scaling Group"
  default     = 2
}

variable "alb_max_size" {
  type        = number
  description = "Maximum size for the Application Load Balancer"
  default     = 4
}

variable "alb_min_size" {
  type        = number
  description = "Minimum size for the Application Load Balancer"
  default     = 1
}