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
