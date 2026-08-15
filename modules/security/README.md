# Security Module

Reusable Terraform security foundation for the AWS platform.

## Features

- ALB Security Group
- Application Security Group
- Database Security Group
- Security Group-to-Security Group rules
- VPC Flow Logs
- CloudWatch Log Group
- Dedicated IAM role for VPC Flow Logs

## Security Flow

Internet
    |
    v
ALB Security Group
    |
    v
Application Security Group
    |
    v
Database Security Group

## Principles

- No direct internet access to application workloads
- No direct internet access to databases
- ALB is the internet-facing entry point
- Application access is restricted to the ALB
- Database access is restricted to application workloads
- Network traffic is logged for visibility
