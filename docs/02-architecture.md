# Architecture

## Overview

This document explains the architecture of the AWS Production Infrastructure Platform.

The project was designed as a production-style AWS environment using Terraform.

The infrastructure was divided into separate layers:

- Networking
- Security
- IAM
- Compute
- DNS
- Certificates
- Logging
- CI/CD

The infrastructure was deployed as a DEV environment in the AWS Hyderabad region.

```text
AWS Region: ap-south-2
Region Name: Asia Pacific (Hyderabad)
Environment: DEV
