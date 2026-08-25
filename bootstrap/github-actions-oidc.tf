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
# GitHub Actions Terraform CI Policy
#
# Purpose:
# - Read Terraform remote state
# - Manage Terraform state locks
# - Read KMS-encrypted Terraform state
# - Perform AWS resource discovery
# - Refresh Terraform-managed resources
#
# This role is intentionally read-only for
# infrastructure resources.
# ==================================================

resource "aws_iam_policy" "github_actions_terraform_ci" {
  #checkov:skip=CKV_AWS_355:Several AWS read-only discovery APIs require Resource "*".
  #checkov:skip=CKV_AWS_288:Policy is intentionally limited to Terraform backend access and read-only resource discovery.

  name        = "GitHubActions-Terraform-CI"
  description = "Read-only access required by GitHub Actions Terraform CI"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      # ----------------------------------------------
      # Terraform State Bucket - List
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
      # Terraform State Files - Read
      # ----------------------------------------------

      {
        Sid    = "TerraformStateRead"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]

        Resource = [
          "arn:aws:s3:::aws-production-platform-terraform-state/environments/dev/terraform.tfstate",
          "arn:aws:s3:::aws-production-platform-terraform-state/global/acm/terraform.tfstate",
          "arn:aws:s3:::aws-production-platform-terraform-state/global/route53/terraform.tfstate"
        ]
      },

      # ----------------------------------------------
      # Terraform State Locks
      #
      # Required by Terraform S3 backend locking.
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
          "arn:aws:s3:::aws-production-platform-terraform-state/environments/dev/terraform.tfstate.tflock",
          "arn:aws:s3:::aws-production-platform-terraform-state/global/acm/terraform.tfstate.tflock",
          "arn:aws:s3:::aws-production-platform-terraform-state/global/route53/terraform.tfstate.tflock"
        ]
      },

      # ----------------------------------------------
      # Terraform State KMS Access
      #
      # Required to decrypt encrypted Terraform state.
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
      # EC2 / VPC Discovery
      #
      # Required for Terraform refresh, data sources,
      # and infrastructure planning.
      # ----------------------------------------------

      {
        Sid    = "EC2Discovery"
        Effect = "Allow"

        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses",
          "ec2:DescribeAddressesAttribute",
          "ec2:DescribeFlowLogs",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeTags"
        ]

        Resource = "*"
      },

      {
        Sid    = "S3Discovery"
        Effect = "Allow"

        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketLocation",
          "s3:GetBucketLogging",
          "s3:GetBucketNotification",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketPolicy",
          "s3:GetBucketPolicyStatus",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:GetObjectLockConfiguration",
          "s3:GetBucketIntelligentTieringConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:ListBucket"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # Elastic Load Balancing v2 Discovery
      #
      # Required for Terraform to refresh existing:
      # - Application Load Balancers
      # - Target Groups
      # - Listeners
      # - Target health
      # ----------------------------------------------

      {
        Sid    = "ELBv2Discovery"
        Effect = "Allow"

        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # Auto Scaling Discovery
      #
      # Required for Terraform plan/state refresh
      # ----------------------------------------------

      {
        Sid    = "AutoScalingDiscovery"
        Effect = "Allow"

        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribePolicies"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # AWS SSM Public Parameters
      #
      # Required for Amazon Linux AMI lookup.
      # ----------------------------------------------

      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter"
        ]

        Resource = "arn:aws:ssm:ap-south-2::parameter/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
      },

      # ----------------------------------------------
      # Route 53 Discovery
      #
      # Required for:
      # - Hosted zone data sources
      # - DNS record refresh
      # - Hosted zone tag discovery
      # ----------------------------------------------

      {
        Sid    = "Route53Discovery"
        Effect = "Allow"

        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResource"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # S3 ALB Access Logs Bucket Discovery
      #
      # Required to refresh the Terraform-managed
      # ALB access log bucket configuration.
      # ----------------------------------------------

      {
        Sid    = "S3ALBLogsDiscovery"
        Effect = "Allow"

        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketOwnershipControls",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetBucketVersioning",
          "s3:GetBucketLogging",
          "s3:GetBucketLocation"
        ]

        Resource = "arn:aws:s3:::dev-platform-alb-access-logs"
      },

      # ----------------------------------------------
      # KMS Discovery
      #
      # Required to refresh the KMS key used for
      # WAF logging infrastructure.
      # ----------------------------------------------

      {
        Sid    = "KMSDiscovery"
        Effect = "Allow"

        Action = [
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:ListResourceTags",
          "kms:ListAliases"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # WAFv2 Discovery
      #
      # Required to refresh the Application Load
      # Balancer Web ACL and associated resources.
      # ----------------------------------------------

      {
        Sid    = "WAFv2Discovery"
        Effect = "Allow"

        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetLoggingConfiguration",
          "wafv2:GetWebACLForResource",
          "wafv2:ListTagsForResource",
          "wafv2:ListResourcesForWebACL"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # IAM Policy Discovery
      #
      # Required to refresh Terraform-managed IAM
      # policies and permission boundaries.
      # ----------------------------------------------

      {
        Sid    = "IAMPolicyDiscovery"
        Effect = "Allow"

        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole",
          "iam:GetInstanceProfile",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:GetRolePolicy"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # CloudWatch Logs Discovery
      #
      # Required for Terraform to read existing
      # CloudWatch Log Groups during plan.
      # ----------------------------------------------

      {
        Sid    = "CloudWatchLogsDiscovery"
        Effect = "Allow"

        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:ListTagsForResource"
        ]

        Resource = "*"
      },

      # ----------------------------------------------
      # IAM Access Analyzer Discovery
      #
      # Required for Terraform to read existing
      # Access Analyzer resources during plan.
      # ----------------------------------------------

      {
        Sid    = "AccessAnalyzerDiscovery"
        Effect = "Allow"

        Action = [
          "access-analyzer:GetAnalyzer"
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
# Used only by the GitHub "dev" environment.
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
