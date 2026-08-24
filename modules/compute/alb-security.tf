data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  #checkov:skip=CKV_AWS_18:Dedicated ALB access-log destination; S3 server access logging is intentionally not enabled to avoid introducing a secondary logging bucket.
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally deferred until an explicit ALB log disaster-recovery and RPO requirement is defined.
  #checkov:skip=CKV_AWS_145:ALB access-log bucket uses explicit SSE-S3 AES256 encryption; KMS is not required for this logging design.
  #checkov:skip=CKV2_AWS_62:No event-driven consumer currently requires S3 notifications for ALB access logs.
  #checkov:skip=CKV2_AWS_61:Lifecycle is implemented through aws_s3_bucket_lifecycle_configuration.alb_logs; Checkov root-scan correlation does not associate the dedicated resource with this bucket.
  #checkov:skip=CKV_AWS_21:Versioning is implemented through aws_s3_bucket_versioning.alb_logs; Checkov root-scan correlation does not associate the dedicated resource with this bucket.
  #checkov:skip=CKV2_AWS_6:Public access blocking is implemented through aws_s3_bucket_public_access_block.alb_logs; Checkov root-scan correlation does not associate the dedicated resource with this bucket.

  count = var.enable_access_logs ? 1 : 0

  bucket = "${var.name}-alb-access-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-access-logs"
      Tier = "logging"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "alb-access-log-retention"
    status = "Enabled"

    expiration {
      days = var.alb_log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowElasticLoadBalancingLogDelivery"
        Effect = "Allow"

        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"

        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:elasticloadbalancing:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:loadbalancer/*"
          }
        }
      }
    ]
  })
}

resource "aws_kms_key" "waf_logs" {
  count = var.enable_waf ? 1 : 0

  description             = "KMS key for ALB WAF CloudWatch logs."
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
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
          Service = "logs.${data.aws_region.current.region}.amazonaws.com"
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
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${var.name}-alb"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-waf-logs-kms"
      Tier = "security"
    }
  )
}

resource "aws_kms_alias" "waf_logs" {
  count = var.enable_waf ? 1 : 0

  name          = "alias/${var.name}-alb-waf-logs"
  target_key_id = aws_kms_key.waf_logs[0].key_id
}

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf ? 1 : 0

  name              = "aws-waf-logs-${var.name}-alb"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.waf_logs[0].arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-waf-logs"
      Tier = "security"
    }
  )
}

resource "aws_wafv2_web_acl" "alb" {
  #checkov:skip=CKV2_AWS_31:WAF logging is configured by aws_wafv2_web_acl_logging_configuration.alb in this module. Both resources use the same enable_waf condition, and the logging configuration directly references this Web ACL ARN.
  count = var.enable_waf ? 1 : 0

  name  = "${var.name}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-alb-waf-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-alb-waf-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-alb-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-waf"
      Tier = "security"
    }
  )
}

resource "aws_wafv2_web_acl_logging_configuration" "alb" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_wafv2_web_acl.alb[0].arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf[0].arn
  ]
}

resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_lb.app.arn
  web_acl_arn  = aws_wafv2_web_acl.alb[0].arn
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.alb_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

