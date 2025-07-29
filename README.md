# AWS Infrastructure Documentation

This repository contains Terraform configuration for a scalable and secure AWS infrastructure setup. The infrastructure is designed with a focus on security, high availability, and best practices.

## Architecture Overview

```ascii
                                     AWS Cloud (ap-southeast-1)
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  ┌─────────────┐          VPC (10.0.0.0/16)                                  │
│  │             │    ┌────────────────────────────────────────────────┐       │
│  │   Client    │    │                                                │       │
│  │             │    │  ┌──────────────┐        Public Subnets        │       │
│  └──────┬──────┘    │  │              │     ┌──────────────────┐     │       │
│         │           │  │     API      │     │                  │     │       │
│         │           │  │   Gateway    │     │    Application   │     │       │
│         └──────────────►   (HTTP)     │────►    Load Balancer  │     │       │
│                     │  │              │     │                  │     │       │
│                     │  └──────┬───────┘     └────────┬─────────┘     │       │
│                     │         │                      │               │       │
│                     │         │                      │               │       │
│                     │  ┌──────▼──────┐               │               │       │
│                     │  │   VPC Link  │               │               │       │
│                     │  └──────┬──────┘               │               │       │
│                     │         │                      │               │       │
│                     │         │      Private Subnets │               │       │
│                     │         │     ┌────────────────▼─┐             │       │
│                     │         │     │                  │             │       │
│                     │         └─────►  EC2 Instances   │             │       │
│                     │               │   (Apache)       │             │       │
│                     │               │                  │             │       │
│                     │               └──────────────────┘             │       │
│                     │                                                │       │
│                     └────────────────────────────────────────────────┘       │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

The infrastructure consists of the following components:

### Network Layer
- **VPC**: A dedicated VPC with CIDR block `10.0.0.0/16`
- **Subnets**:
  - Public Subnets: `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24`
  - Private Subnets: `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.0/24`
- **Internet Gateway**: Provides internet access for public subnets
- **Route Tables**: Configured for public subnet internet access

### Security Layer
- **Security Groups**:
  - ALB Security Group:
    - Inbound: HTTP (80) from anywhere
    - Outbound: All traffic allowed
  - EC2 Security Group:
    - Inbound: HTTP (80) from ALB only
    - Outbound: All traffic allowed

### Application Layer
- **Application Load Balancer (ALB)**:
  - Deployed in public subnets
  - HTTP listener on port 80
  - Health checks configured
  - Routes traffic to EC2 instances in private subnets

- **EC2 Instances**:
  - Deployed in private subnets via Auto Scaling Group
  - Initial capacity: 2 instances
  - Scaling limits: Min 1, Max 4 instances
  - Using Amazon Linux 2 AMI
  - t2.micro instance type
  - Apache web server installed and configured
  - Auto-configured via user data script
  - Automatically registered with ALB target group

### Request Flow
1. Client makes HTTP request to ALB DNS name
2. Request reaches Internet Gateway (entry point to VPC)
3. Traffic flows to ALB in public subnet through IGW
4. ALB security group allows incoming HTTP (port 80)
5. ALB forwards request to healthy EC2 instance(s) in private subnet
6. EC2 security group allows traffic only from ALB
7. EC2 instance processes request and returns response
8. Response follows reverse path through ALB back to client

### Detailed Flow Diagrams

#### 1. Architecture Flow
```
                                     Request Flow
┌─────────┐     ┌─────────┐     ┌──────────────┐     ┌─────────┐     ┌──────────┐
│         │  1  │         │  2  │    Public    │  3  │         │  4  │  Private │
│ Client  ├────►│   IGW   ├────►│   Subnet     ├────►│   ALB   ├────►│  Subnet  │
│         │     │         │     │              │     │         │     │          │
└─────────┘     └─────────┘     └──────────────┘     └─────────┘     └──────────┘
     ▲                                                                     │
     │                                                                     │
     └─────────────────────────────── 5 ◄──────────────────────────--------┘
                               Response Flow

1. Client sends HTTP request
2. IGW routes traffic to VPC
3. Request reaches ALB in public subnet
4. ALB routes to healthy EC2 instance
5. Response returns through same path
```

#### 2. Security Flow
```
                                Security Groups
┌──────────┐              ┌────────────────┐              ┌────────────────┐
│          │              │   ALB SG       │              │   EC2 SG       │
│  Client  │              │                │              │                │
│          │──── :80 ────►│  Inbound:      │─── :80 ─────►│  Inbound:      │
└──────────┘              │  - Port 80     │              │  - Port 80     │
                          │  - From: Any   │              │  - From: ALB SG│
                          │                │              │                │
                          │  Outbound:     │              │  Outbound:     │
                          │  - All Traffic │              │  - All Traffic │
                          └────────────────┘              └────────────────┘
```

#### 3. Network Segmentation
```
┌─────────────────────────────── VPC (10.0.0.0/16) ──────────────────────────┐
│                                                                            │
│  ┌─────────────────────┐                     ┌──────────────────────┐      │
│  │   Public Subnets    │                     │   Private Subnets    │      │
│  │                     │                     │                      │      │
│  │ - 10.0.1.0/24       │      Internal       │ - 10.0.4.0/24        │      │
│  │ - 10.0.2.0/24       │──── Traffic ──────► │ - 10.0.5.0/24        │      │
│  │ - 10.0.3.0/24       │                     │ - 10.0.6.0/24        │      │
│  │                     │                     │                      │      │
│  │ Contains: ALB       │                     │ Contains: EC2s       │      │
│  └─────────────────────┘                     └──────────────────────┘      │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

Note: API Gateway integration is prepared in the configuration (currently commented) for future use.

## Infrastructure Details

### Networking
- Region: ap-southeast-1 (Singapore)
- Availability Zones: Supports up to 3 AZs
- VPC CIDR: 10.0.0.0/16
- Public Subnets: 3 subnets (one per AZ)
- Private Subnets: 3 subnets (one per AZ)

### Security
- Layered security approach
- Private instances not directly accessible from internet
- Traffic flow controlled via security groups
- ALB acts as security boundary

### Scalability
- Multi-AZ setup for high availability
- Launch template ready for auto-scaling
- ALB distributes traffic across instances

## Getting Started

### Prerequisites
- AWS Account
- Terraform installed
- AWS CLI configured

### Deployment
1. Clone this repository
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Review the plan:
   ```bash
   terraform plan
   ```
4. Apply the configuration:
   ```bash
   terraform apply
   ```
5. Destory the infrastructure when done:
   ```bash
   terraform destroy
   ```

### Access Details
After deployment, you can access the application in two ways:

1. Get the complete URL:
   ```bash
   terraform output application_endpoint
   ```

2. Get just the ALB DNS name:
   ```bash
   terraform output load_balancer | grep dns_name
   ```

The application will be accessible via HTTP on port 80.

## Maintenance and Updates

### Adding New Instances
- Update the launch template configuration as needed
- Instances will be automatically added to ALB target group

### Security Updates
- Security group rules can be modified in the Terraform configuration
- EC2 instances automatically receive updates via user data script

## Best Practices Implemented
1. Multi-AZ deployment for high availability
2. Private subnets for application tier
3. Security groups with principle of least privilege
4. API Gateway as secure entry point
5. VPC Link for secure internal communication

## Variables and Customization
The infrastructure can be customized through variables in `variables.tf`:
- CIDR ranges
- Availability Zones
- Instance types
- AMI IDs
