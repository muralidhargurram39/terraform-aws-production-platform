variable "name" {
  description = "Name prefix for IAM resources."
  type        = string
}

variable "enable_ec2_role" {
  description = "Create the EC2 instance role."
  type        = bool
  default     = true
}

variable "enable_cicd_role" {
  description = "Create the CI/CD role."
  type        = bool
  default     = true
}

variable "enable_auditor_role" {
  description = "Create the read-only auditor role."
  type        = bool
  default     = true
}

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
