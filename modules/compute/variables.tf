variable "name" {
  description = "Name prefix for compute resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where compute resources will be deployed."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs used by the Application Load Balancer."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnets are required for the ALB."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the Auto Scaling Group."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnets are required for the ASG."
  }
}

variable "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID for application EC2 instances."
  type        = string
}

variable "ec2_instance_profile_name" {
  description = "IAM instance profile attached to EC2 instances."
  type        = string
}

variable "ami_id" {
  description = "AMI ID used by the Launch Template. If empty, the latest Amazon Linux 2023 AMI is selected."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "Root volume size must be at least 8 GiB."
  }
}

variable "min_size" {
  description = "Minimum number of EC2 instances."
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances."
  type        = number
  default     = 6
}

variable "health_check_grace_period" {
  description = "ASG health check grace period in seconds."
  type        = number
  default     = 300
}

variable "cpu_target_value" {
  description = "Target average CPU utilization for ASG target tracking."
  type        = number
  default     = 60
}

variable "application_port" {
  description = "Application port exposed by EC2 instances."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP health check path."
  type        = string
  default     = "/health"
}

variable "user_data" {
  description = "Optional EC2 user-data script."
  type        = string
  default     = ""
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}
