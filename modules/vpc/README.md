# VPC Module

Reusable Terraform module for provisioning a highly available AWS VPC.

## Features

- VPC
- Internet Gateway
- Public subnets
- Private subnets
- Isolated subnets
- NAT Gateway per Availability Zone
- Public route table
- Private route tables
- Isolated route tables
- DNS support
- DNS hostnames
- Environment-independent configuration

## Network Tiers

### Public

Internet-facing resources such as:

- Application Load Balancers
- NAT Gateways

### Private

Application workloads such as:

- EC2
- Auto Scaling Groups

### Isolated

Resources that should not have direct internet access.

Examples:

- Databases
- Internal services
- Data workloads
