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
  single_nat_gateway = true

  tags = local.common_tags
}

module "security" {
  source = "../../modules/security"

  name = "${var.environment}-platform"

  vpc_id = module.vpc.vpc_id

  app_port = 8080

  db_port = 5432

  allowed_http_cidr_blocks = [
    "0.0.0.0/0"
  ]

  allowed_https_cidr_blocks = [
    "0.0.0.0/0"
  ]

  enable_flow_logs = true

  flow_log_retention_days = 30

  tags = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name = "${var.environment}-platform"

  enable_ec2_role        = true
  enable_cicd_role       = true
  enable_auditor_role    = true
  enable_access_analyzer = true

  tags = local.common_tags
}

module "compute" {
  source = "../../modules/compute"

  name = "${var.environment}-platform"

  vpc_id = module.vpc.vpc_id

  public_subnet_ids = module.vpc.public_subnet_ids

  private_subnet_ids = module.vpc.private_subnet_ids

  alb_security_group_id = module.security.alb_security_group_id

  app_security_group_id = module.security.app_security_group_id

  ec2_instance_profile_name = module.iam.ec2_instance_profile_name

  instance_type = "t3.micro"

  min_size         = 2
  desired_capacity = 2
  max_size         = 6

  application_port = 8080

  health_check_path = "/health"

  cpu_target_value = 60

  user_data = file("${path.root}/../../scripts/app-bootstrap.sh")

  tags = local.common_tags
}
