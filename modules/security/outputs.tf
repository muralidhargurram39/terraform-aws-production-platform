output "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID for application workloads."
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "Security group ID for database workloads."
  value       = aws_security_group.db.id
}

output "flow_log_id" {
  description = "VPC Flow Log ID."
  value       = try(aws_flow_log.vpc[0].id, null)
}

output "flow_log_group_name" {
  description = "CloudWatch Log Group for VPC Flow Logs."
  value       = try(aws_cloudwatch_log_group.vpc_flow_logs[0].name, null)
}

output "flow_logs_role_arn" {
  description = "IAM role ARN used by VPC Flow Logs."
  value       = try(aws_iam_role.flow_logs[0].arn, null)
}
