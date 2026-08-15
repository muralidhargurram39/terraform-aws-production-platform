output "vpc_id" {
  description = "Dev VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Dev VPC CIDR."
  value       = module.vpc.vpc_cidr_block
}

output "availability_zones" {
  description = "Availability Zones used by the dev VPC."
  value       = local.availability_zones
}

output "public_subnet_ids" {
  description = "Dev public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Dev private subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "isolated_subnet_ids" {
  description = "Dev isolated subnet IDs."
  value       = module.vpc.isolated_subnet_ids
}

output "nat_gateway_ids" {
  description = "Dev NAT Gateway IDs."
  value       = module.vpc.nat_gateway_ids
}

output "alb_security_group_id" {
  description = "Dev ALB security group."
  value       = module.security.alb_security_group_id
}

output "app_security_group_id" {
  description = "Dev application security group."
  value       = module.security.app_security_group_id
}

output "db_security_group_id" {
  description = "Dev database security group."
  value       = module.security.db_security_group_id
}

output "flow_log_id" {
  description = "Dev VPC Flow Log."
  value       = module.security.flow_log_id
}

output "flow_log_group_name" {
  description = "Dev VPC Flow Log CloudWatch Log Group."
  value       = module.security.flow_log_group_name
}
