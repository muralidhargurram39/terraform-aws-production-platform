# Terraform CI/CD Pipeline Test

This file is used to test the GitHub Actions Terraform CI/CD pipeline.

Expected workflow:

Feature branch
→ Terraform CI
→ Terraform fmt
→ Terraform validate
→ TFLint
→ Checkov
→ Terraform plan artifact
→ Pull Request to main
→ Merge
→ Terraform apply
