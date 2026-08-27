# AWS Production Infrastructure Platform

A production-style AWS infrastructure project built using **Terraform**, **AWS**, and **GitHub Actions**.

This project was created to practice designing, deploying, securing, and managing AWS infrastructure using Infrastructure as Code (IaC).

> **Current Status:** The DEV environment has been destroyed. This repository is retained as a reference for the infrastructure design, Terraform modules, AWS architecture, and CI/CD implementation.

---

# Project Overview

This project provisions AWS infrastructure using reusable Terraform modules.

The DEV environment included:

- Virtual Private Cloud (VPC)
- Public, private, and isolated subnets
- Internet Gateway
- NAT Gateway
- Route Tables
- Security Groups
- Application Load Balancer (ALB)
- Auto Scaling Group
- EC2 instances
- IAM roles and policies
- AWS WAF
- Amazon S3 for ALB access logs
- Amazon CloudWatch
- VPC Flow Logs
- AWS KMS
- Amazon Route 53
- AWS Certificate Manager (ACM)

The project also includes GitHub Actions workflows for Terraform validation, planning, and infrastructure deployment.

---

# AWS Region

The DEV infrastructure was deployed in:

| Environment | Region |
|---|---|
| DEV | `ap-south-2` |
| Region Name | Asia Pacific (Hyderabad) |

---

# Architecture Overview

The application architecture followed this general flow:

```text
                         Internet
                            |
                            v
                         Route 53
                            |
                            v
                    Application Load Balancer
                         /              \
                        v                v
                  EC2 Instance      EC2 Instance
                        \                /
                         \              /
                          v            v
                         Auto Scaling Group
                                |
                                v
                         Private Subnets
                                |
                                v
                          Application
