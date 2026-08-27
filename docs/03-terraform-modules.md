# Terraform Modules

## Overview

This project uses reusable Terraform modules to organize the AWS infrastructure.

Instead of defining all AWS resources inside a single Terraform configuration, the infrastructure was divided into separate modules.

The main modules are:

```text
modules/
├── vpc/
├── security/
├── iam/
└── compute/
