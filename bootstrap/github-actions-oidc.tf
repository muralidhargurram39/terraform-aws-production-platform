# ==================================================
# GitHub Actions OIDC Provider
# ==================================================

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github_actions.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name    = "${var.project_name}-github-actions-oidc"
    Managed = "terraform"
  }
}

# ==================================================
# GitHub Actions Terraform CI Role
#
# Used for:
# - terraform init
# - terraform validate
# - terraform plan
#
# Allowed from:
# - feature branches
# - pull requests
# - terraform-ci GitHub environment
# ==================================================

resource "aws_iam_role" "github_actions_terraform_ci" {
  name = "GitHubActions-Terraform-CI"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {

          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:muralidhargurram39/terraform-aws-production-platform:ref:refs/heads/feature/*",
              "repo:muralidhargurram39/terraform-aws-production-platform:pull_request",
              "repo:muralidhargurram39/terraform-aws-production-platform:environment:terraform-ci"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHubActions-Terraform-CI"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = "ci"
  }
}

# ==================================================
# GitHub Actions Terraform CI Policy
#
# Purpose:
# - Read Terraform remote state
# - Manage Terraform state lock
# - Read KMS-encrypted state
# - Perform AWS discovery required for terraform plan
# ==================================================

resource "aws_iam_policy" "github_actions_terraform_ci" {
  name        = "GitHubActions-Terraform-CI"
  description = "Read-only access required by GitHub Actions Terraform CI"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # ----------------------------------------------
      # S3 Terraform State Bucket
      # ----------------------------------------------

      {
        Sid    = "TerraformStateList"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = "arn:aws:s3:::aws-production-platform-terraform-state"
      },

      # ----------------------------------------------
      # Read Terraform State Files
      # ----------------------------------------------

      {
        Sid    = "TerraformStateRead"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]

        Resource = [

          # Dev environment state
          "arn:aws:s3:::aws-production-platform-terraform-state/environments/dev/terraform.tfstate",

          # Global ACM state
          "arn:aws:s3:::aws-production-platform-terraform-state/global/acm/terraform.tfstate",

          # Global Route53 state
          "arn:aws:s3:::aws-production-platform-terraform-state/global/route53/terraform.tfstate"
        ]
      },

      # ----------------------------------------------
      # Terraform State Locks
      # ----------------------------------------------

      {
        Sid    = "TerraformStateLocks"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [

          # Dev environment lock
          "arn:aws:s3:::aws-production-platform-terraform-state/environments/dev/terraform.tfstate.tflock",

          # ACM lock
          "arn:aws:s3:::aws-production-platform-terraform-state/global/acm/terraform.tfstate.tflock",

          # Route53 lock
          "arn:aws:s3:::aws-production-platform-terraform-state/global/route53/terraform.tfstate.tflock"
        ]
      },

      # ----------------------------------------------
      # KMS Access
      #
      # Required to read encrypted Terraform state
      # ----------------------------------------------

      {
        Sid    = "TerraformStateKMS"
        Effect = "Allow"

        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]

        Resource = "arn:aws:kms:ap-south-2:438064565553:key/97382776-c7ee-472f-bbca-868451905c6f"
      },

      # ----------------------------------------------
      # EC2 Read / Discovery
      #
      # Required for Terraform data sources and plan
      # ----------------------------------------------

      {
        Sid    = "EC2Discovery"
        Effect = "Allow"

        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses",
          "ec2:DescribeTags"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # AWS SSM Public Parameters
      #
      # Required for Amazon Linux AMI lookup
      # ----------------------------------------------

      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # AWS Caller Identity
      # ----------------------------------------------

      {
        Sid    = "CallerIdentity"
        Effect = "Allow"

        Action = [
          "sts:GetCallerIdentity"
        ]

        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "GitHubActions-Terraform-CI"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = "ci"
  }
}

# ==================================================
# Attach CI Policy to CI Role
# ==================================================

resource "aws_iam_role_policy_attachment" "github_actions_terraform_ci" {
  role       = aws_iam_role.github_actions_terraform_ci.name
  policy_arn = aws_iam_policy.github_actions_terraform_ci.arn
}

# ==================================================
# GitHub Actions Terraform Dev Apply Role
#
# Used only by the GitHub "dev" environment
# ==================================================

resource "aws_iam_role" "github_actions_terraform_dev_apply" {
  name = "GitHubActions-Terraform-Dev-Apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "GitHubActionsOIDC"
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            "token.actions.githubusercontent.com:sub" = "repo:${var.github_organization}/${var.github_repository}:environment:dev"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHubActions-Terraform-Dev-Apply"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
