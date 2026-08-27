data "aws_caller_identity" "current" {}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption."
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.project_name}-terraform-state-kms"
  }
}

resource "aws_kms_key_policy" "terraform_state" {
  key_id = aws_kms_key.terraform_state.id

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
      }
    ]
  })
}

resource "aws_s3_bucket" "terraform_state" {
  #checkov:skip=CKV_AWS_144:Cross-region replication is intentionally deferred until a formal disaster-recovery architecture and Terraform state RPO requirement are defined.
  #checkov:skip=CKV2_AWS_62:S3 event notifications are not required because this bucket is used exclusively for Terraform remote state and has no event-driven consumer.
  bucket = "${var.project_name}-terraform-state"

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket" "terraform_state_access_logs" {
  #checkov:skip=CKV_AWS_144:Cross-region replication for the dedicated access-log bucket is intentionally deferred until logging disaster-recovery and retention requirements are defined.
  #checkov:skip=CKV2_AWS_62:S3 event notifications are not required because this bucket is dedicated to server access-log storage and currently has no event-driven processing consumer.
  bucket = "${var.project_name}-terraform-state-access-logs"

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.project_name}-terraform-state-access-logs"
    Tier = "logging"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_access_logs" {
  bucket = aws_s3_bucket.terraform_state_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state_access_logs" {
  #checkov:skip=CKV2_AWS_65:BucketOwnerPreferred is intentionally used for the dedicated S3 server access-log destination to support log delivery ownership and ACL requirements.
  bucket = aws_s3_bucket.terraform_state_access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_access_logs" {
  bucket = aws_s3_bucket.terraform_state_access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_access_logs" {
  bucket = aws_s3_bucket.terraform_state_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_access_logs" {
  bucket = aws_s3_bucket.terraform_state_access_logs.id

  rule {
    id     = "access-log-retention"
    status = "Enabled"

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.terraform_state_access_logs.id
  target_prefix = "terraform-state/"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform-state-retention"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
