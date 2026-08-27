locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy   = "Terraform"
      Project     = "aws-production-platform"
      Environment = var.environment
      Module      = "route53"
    }
  )
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "route53_dnssec" {
  provider = aws.us_east_1

  description              = "KMS key for Route 53 DNSSEC signing."
  customer_master_key_spec = "ECC_NIST_P256"
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = 30

  lifecycle {
    prevent_destroy = false
  }

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRoute53DNSSECService"
        Effect = "Allow"

        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }

        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:Verify"
        ]

        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.domain_name}-route53-dnssec"
      Tier = "security"
    }
  )
}

resource "aws_kms_alias" "route53_dnssec" {
  provider = aws.us_east_1

  name          = "alias/${replace(var.domain_name, ".", "-")}-route53-dnssec"
  target_key_id = aws_kms_key.route53_dnssec.key_id
}

resource "aws_route53_zone" "this" {
  name = var.domain_name

  comment = "Public hosted zone for ${var.domain_name}"

  tags = local.common_tags
}

resource "aws_route53_key_signing_key" "this" {
  hosted_zone_id             = aws_route53_zone.this.zone_id
  key_management_service_arn = aws_kms_key.route53_dnssec.arn
  name                       = "route53-dnssec"

  depends_on = [
    aws_kms_key.route53_dnssec
  ]
}

resource "aws_route53_hosted_zone_dnssec" "this" {
  hosted_zone_id = aws_route53_zone.this.zone_id

  depends_on = [
    aws_route53_key_signing_key.this
  ]
}

resource "aws_kms_key" "route53_query_logs" {
  provider = aws.us_east_1

  description             = "KMS key for Route 53 query logs."
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = false
  }

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountAdministration"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUseOfKey"
        Effect = "Allow"

        Principal = {
          Service = "logs.us-east-1.amazonaws.com"
        }

        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]

        Resource = "*"

        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/route53/${var.domain_name}/query-logs"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.domain_name}-route53-query-logs"
      Tier = "security"
    }
  )
}

resource "aws_kms_alias" "route53_query_logs" {
  provider = aws.us_east_1

  name          = "alias/${replace(var.domain_name, ".", "-")}-route53-query-logs"
  target_key_id = aws_kms_key.route53_query_logs.key_id
}

resource "aws_cloudwatch_log_group" "route53_query_logs" {
  provider = aws.us_east_1

  name              = "/aws/route53/${var.domain_name}/query-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.route53_query_logs.arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.domain_name}-route53-query-logs"
      Tier = "logging"
    }
  )
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_logs" {
  provider = aws.us_east_1

  policy_name = "${replace(var.domain_name, ".", "-")}-route53-query-logs"

  policy_document = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowRoute53QueryLogging"
        Effect = "Allow"

        Principal = {
          Service = "route53.amazonaws.com"
        }

        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "${aws_cloudwatch_log_group.route53_query_logs.arn}:*"
      }
    ]
  })
}
resource "aws_route53_query_log" "this" {
  provider = aws.us_east_1

  zone_id = aws_route53_zone.this.zone_id

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_logs.arn

  depends_on = [
    aws_cloudwatch_log_resource_policy.route53_query_logs
  ]
}

resource "aws_route53_record" "dev" {
  #checkov:skip=CKV2_AWS_23:The alias target is an ALB provided through dev_alb_dns_name and dev_alb_zone_id variables; Checkov cannot resolve this cross-module attachment during static analysis.
  count = var.dev_alb_dns_name != "" && var.dev_alb_zone_id != "" ? 1 : 0

  zone_id = aws_route53_zone.this.zone_id
  name    = "dev.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.dev_alb_dns_name
    zone_id                = var.dev_alb_zone_id
    evaluate_target_health = true
  }
}
