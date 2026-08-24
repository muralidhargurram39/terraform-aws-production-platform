locals {
  common_tags = merge(
    var.tags,
    {
      Module = "security"
    }
  )
}

resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to the ALB in the compute module via module output.
  name        = "${var.name}-alb-sg"
  description = "Security group for the Application Load Balancer."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-alb-sg"
      Tier = "alb"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:HTTP port 80 is intentionally exposed only for the ALB HTTP-to-HTTPS 301 redirect; application traffic is served through HTTPS.
  for_each = toset(var.allowed_http_cidr_blocks)

  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = each.value
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  description = "Allow HTTP traffic to the ALB."
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.allowed_https_cidr_blocks)

  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = each.value
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"

  description = "Allow HTTPS traffic to the ALB."
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow ALB outbound traffic."
}

resource "aws_security_group" "app" {
  #checkov:skip=CKV2_AWS_5:Security group is attached to EC2 instances through the compute module Launch Template.
  name        = "${var.name}-app-sg"
  description = "Security group for application workloads."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-app-sg"
      Tier = "application"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id

  referenced_security_group_id = aws_security_group.alb.id

  from_port   = var.app_port
  to_port     = var.app_port
  ip_protocol = "tcp"

  description = "Allow application traffic only from the ALB."
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow application outbound traffic."
}

resource "aws_security_group" "db" {
  #checkov:skip=CKV2_AWS_5:Reserved for the database tier, which is not yet implemented in this infrastructure stage.
  name        = "${var.name}-db-sg"
  description = "Security group for database workloads."
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-db-sg"
      Tier = "database"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.app.id

  from_port   = var.db_port
  to_port     = var.db_port
  ip_protocol = "tcp"

  description = "Allow database traffic only from application workloads."
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"

  description = "Allow database outbound traffic."
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  description             = "KMS key for VPC Flow Logs CloudWatch log group."
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
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/${var.name}/flow-logs"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-vpc-flow-logs-kms"
    }
  )
}

resource "aws_kms_alias" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name          = "alias/${var.name}-vpc-flow-logs"
  target_key_id = aws_kms_key.vpc_flow_logs[0].key_id
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days

  kms_key_id = aws_kms_key.vpc_flow_logs[0].arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-vpc-flow-logs"
    }
  )
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"

        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }

          ArnLike = {
            "aws:SourceArn" = "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-vpc-flow-logs-role"
    }
  )
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowCreateLogStream"
        Effect = "Allow"

        Action = [
          "logs:CreateLogStream"
        ]

        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
      },
      {
        Sid    = "AllowPutLogEvents"
        Effect = "Allow"

        Action = [
          "logs:PutLogEvents"
        ]

        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
      },
      {
        Sid    = "AllowDescribeLogStreams"
        Effect = "Allow"

        Action = [
          "logs:DescribeLogStreams"
        ]

        Resource = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id = var.vpc_id

  traffic_type = "ALL"

  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn

  max_aggregation_interval = 60

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-vpc-flow-log"
    }
  )

  depends_on = [
    aws_iam_role_policy.flow_logs
  ]
}


