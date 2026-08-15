variable "name" {
  description = "Name prefix for VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Availability Zones used by the VPC."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 3
    error_message = "At least three Availability Zones are required for this platform."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Public subnet count must match Availability Zone count."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "Private subnet count must match Availability Zone count."
  }
}

variable "isolated_subnet_cidrs" {
  description = "CIDR blocks for isolated subnets."
  type        = list(string)

  validation {
    condition     = length(var.isolated_subnet_cidrs) == length(var.availability_zones)
    error_message = "Isolated subnet count must match Availability Zone count."
  }
}

variable "enable_nat_gateway" {
  description = "Whether NAT Gateways should be created."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether VPC Flow Logs should be enabled."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to VPC resources."
  type        = map(string)
  default     = {}
}
