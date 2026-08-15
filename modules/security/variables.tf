variable "name" {
  description = "Name prefix for security resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created."
  type        = string
}

variable "allowed_http_cidr_blocks" {
  description = "CIDR blocks allowed to access HTTP on the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidr_blocks" {
  description = "CIDR blocks allowed to access HTTPS on the ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Application port exposed behind the ALB."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch retention period for VPC Flow Logs."
  type        = number
  default     = 30

  validation {
    condition     = var.flow_log_retention_days >= 1
    error_message = "Flow log retention must be at least 1 day."
  }
}

variable "tags" {
  description = "Additional tags for security resources."
  type        = map(string)
  default     = {}
}
