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
# Terraform CI Role
# Feature branches, Pull Requests and CI environment
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
              "repo:muralidhargurram39@298685762/terraform-aws-production-platform@1334950847:ref:refs/heads/feature/*",
              "repo:muralidhargurram39@298685762/terraform-aws-production-platform@1334950847:pull_request",
              "repo:muralidhargurram39@298685762/terraform-aws-production-platform@1334950847:environment:terraform-ci"
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
# Terraform CI Policy
# Read-only access to Terraform remote state
# ==================================================

resource "aws_iam_policy" "github_actions_terraform_ci" {
  name        = "GitHubActions-Terraform-CI"
  description = "Read-only access required by GitHub Actions Terraform CI"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # ------------------------------------------
      # List Terraform state bucket
      # ------------------------------------------

      {
        Sid    = "TerraformStateList"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = aws_s3_bucket.terraform_state.arn
      },

      # ------------------------------------------
      # Read Terraform state
      # ------------------------------------------

      {
        Sid    = "TerraformStateRead"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]

        Resource = [
          "${aws_s3_bucket.terraform_state.arn}/environments/dev/terraform.tfstate"
        ]
      },

      # ------------------------------------------
      # Read Terraform state encryption key
      # ------------------------------------------

      {
        Sid    = "TerraformStateKMS"
        Effect = "Allow"

        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]

        Resource = aws_kms_key.terraform_state.arn
      },

      # ------------------------------------------
      # Verify AWS identity
      # ------------------------------------------

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

resource "aws_iam_role" "github_actions_terraform_dev_apply" {
  name = "GitHubActions-Terraform-Dev-Apply"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
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
