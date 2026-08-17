variable "domain_name" {
  description = "Domain name for the ACM certificate."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "domain_name must be a valid DNS domain name."
  }
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID used for ACM DNS validation."
  type        = string
}

variable "environment" {
  description = "Environment represented by this certificate."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Additional tags for ACM resources."
  type        = map(string)
  default     = {}
}
