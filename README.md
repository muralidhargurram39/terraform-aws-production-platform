# AWS Production Infrastructure Platform

Production-grade AWS infrastructure built using reusable Terraform modules.

## Objectives

This project provisions a secure, highly available and disaster-recovery-ready AWS platform supporting:

- Development
- Staging
- Production

## Architecture

The platform is designed around:

- Multi-AZ networking
- Public, private and isolated subnets
- NAT Gateway per Availability Zone
- Application Load Balancer
- Auto Scaling Group
- Least-privilege IAM
- Route53
- ACM
- CloudFront
- S3
- Cross-region disaster recovery

## Primary Region

`ap-south-2` — Asia Pacific (Hyderabad)

## Disaster Recovery Region

`ap-southeast-1` — Asia Pacific (Singapore)

## Technology Stack

- Terraform
- AWS VPC
- EC2
- Application Load Balancer
- Auto Scaling
- IAM
- Route53
- ACM
- CloudFront
- S3

## Repository Structure

```text
modules/
    vpc/
    security/
    iam/
    alb/
    compute/
    dns/
    acm/
    cloudfront/
    dr/

environments/
    dev/
    staging/
    prod/

global/
    route53/
    acm/
    cloudfront/

bootstrap/
    Terraform remote-state infrastructure
