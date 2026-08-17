variable "domain_name" {
  description = "Root domain name."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "domain_name must be a valid DNS domain name."
  }
}

variable "environment" {
  description = "Environment associated with this DNS zone."
  type        = string
  default     = "global"
}

variable "tags" {
  description = "Additional tags for Route 53 resources."
  type        = map(string)
  default     = {}
}
