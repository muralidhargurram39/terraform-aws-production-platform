output "ec2_role_name" {
  description = "EC2 IAM role name."
  value       = try(aws_iam_role.ec2[0].name, null)
}

output "ec2_role_arn" {
  description = "EC2 IAM role ARN."
  value       = try(aws_iam_role.ec2[0].arn, null)
}

output "ec2_instance_profile_name" {
  description = "EC2 instance profile name."
  value       = try(aws_iam_instance_profile.ec2[0].name, null)
}

output "ec2_permission_boundary_arn" {
  description = "EC2 permission boundary ARN."
  value       = try(aws_iam_policy.ec2_boundary[0].arn, null)
}

output "cicd_role_name" {
  description = "CI/CD IAM role name."
  value       = try(aws_iam_role.cicd[0].name, null)
}

output "cicd_role_arn" {
  description = "CI/CD IAM role ARN."
  value       = try(aws_iam_role.cicd[0].arn, null)
}

output "auditor_role_name" {
  description = "Auditor IAM role name."
  value       = try(aws_iam_role.auditor[0].name, null)
}

output "auditor_role_arn" {
  description = "Auditor IAM role ARN."
  value       = try(aws_iam_role.auditor[0].arn, null)
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer ARN."
  value       = try(aws_accessanalyzer_analyzer.this[0].arn, null)
}
