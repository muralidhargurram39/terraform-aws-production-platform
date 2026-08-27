# Project Overview

## Introduction

AWS Production Infrastructure Platform is a hands-on DevOps and Cloud Infrastructure project built using Terraform and AWS.

The purpose of this project was to practice designing, deploying, securing, and managing a production-style AWS environment using Infrastructure as Code.

The infrastructure was organized using reusable Terraform modules and included networking, security, compute, IAM, logging, DNS, certificates, and CI/CD automation.

The project was deployed in AWS and later fully destroyed after completion to avoid unnecessary cloud costs.

---

## Project Objectives

The main objectives of this project were:

- Build AWS infrastructure using Terraform.
- Follow a modular Infrastructure as Code design.
- Create a highly available network architecture.
- Deploy applications behind an Application Load Balancer.
- Use Auto Scaling for EC2 instances.
- Implement security groups and least-privilege IAM.
- Enable VPC Flow Logs and ALB access logging.
- Protect the Application Load Balancer using AWS WAF.
- Use AWS KMS for encryption where required.
- Configure Route 53 for DNS management.
- Configure AWS Certificate Manager for HTTPS.
- Use GitHub Actions for Terraform CI/CD.
- Authenticate GitHub Actions to AWS using OIDC instead of long-lived AWS credentials.
- Use an S3 backend for Terraform remote state.
- Document the infrastructure and cleanup process.

---

## AWS Region

The DEV environment was deployed in:

| Environment | AWS Region |
|---|---|
| DEV | `ap-south-2` |
| Region Name | Asia Pacific (Hyderabad) |

---

## Main Technologies

The following technologies were used in this project:

- Terraform
- AWS
- Amazon VPC
- Amazon EC2
- Auto Scaling Group
- Application Load Balancer
- Amazon S3
- AWS IAM
- AWS KMS
- Amazon CloudWatch
- AWS WAF
- Amazon Route 53
- AWS Certificate Manager
- GitHub Actions
- GitHub OIDC

---

## Infrastructure Overview

The infrastructure was organized into multiple layers.

```text
                         Internet
                            |
                            v
                        Route 53
                            |
                            v
                    Application Load Balancer
                         /              \
                        /                \
                       v                  v
                EC2 Instance        EC2 Instance
                       \                  /
                        \                /
                         +------v-------+
                                |
                                v
                         Private Subnets
                                |
                                v
                        Application Services
