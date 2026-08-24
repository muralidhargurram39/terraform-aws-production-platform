variable "aws_region" {
  description = "AWS region for Terraform state infrastructure."
  type        = string
  default     = "ap-south-2"
}

variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
  default     = "aws-production-platform"
}

variable "github_organization" {
  description = "GitHub organization or username that owns the repository."
  type        = string
  default     = "muralidhargurram39"
}

variable "github_repository" {
  description = "GitHub repository name."
  type        = string
  default     = "terraform-aws-production-platform"
}
