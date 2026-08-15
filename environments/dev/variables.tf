variable "aws_region" {
  description = "AWS deployment region."
  type        = string
  default     = "ap-south-2"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}
