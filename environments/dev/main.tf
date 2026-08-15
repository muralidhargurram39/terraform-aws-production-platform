data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    3
  )

  common_tags = {
    Project     = "aws-production-platform"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Tier        = "dev"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name = "${var.environment}-platform"

  vpc_cidr = "10.20.0.0/16"

  availability_zones = local.availability_zones

  public_subnet_cidrs = [
    "10.20.1.0/24",
    "10.20.2.0/24",
    "10.20.3.0/24"
  ]

  private_subnet_cidrs = [
    "10.20.11.0/24",
    "10.20.12.0/24",
    "10.20.13.0/24"
  ]

  isolated_subnet_cidrs = [
    "10.20.21.0/24",
    "10.20.22.0/24",
    "10.20.23.0/24"
  ]

  enable_nat_gateway = true

  tags = local.common_tags
}
