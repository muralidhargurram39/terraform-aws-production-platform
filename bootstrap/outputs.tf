output "terraform_state_bucket_name" {
  description = "Terraform remote state S3 bucket name."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_state_bucket_arn" {
  description = "Terraform remote state S3 bucket ARN."
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_state_kms_key_arn" {
  description = "KMS key ARN used to encrypt Terraform state."
  value       = aws_kms_key.terraform_state.arn
}

output "github_actions_terraform_ci_role_arn" {
  description = "IAM role ARN used by GitHub Actions Terraform CI workflows."

  value = aws_iam_role.github_actions_terraform_ci.arn
}

output "github_actions_terraform_dev_apply_role_arn" {
  description = "IAM role ARN used by GitHub Actions Terraform Dev Apply workflows."

  value = aws_iam_role.github_actions_terraform_dev_apply.arn
}

output "github_actions_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."

  value = aws_iam_openid_connect_provider.github_actions.arn
}
