locals {
  common_tags = merge(
    var.tags,
    {
      Module = "iam"
    }
  )
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "ec2_boundary" {
  #checkov:skip=CKV_AWS_111:SSM, SSMMessages, and EC2Messages control-plane actions require Resource "*" and are constrained by the EC2 role permissions boundary.
  #checkov:skip=CKV_AWS_108:The EC2 permissions boundary contains only SSM control-plane permissions and does not grant application data-access permissions.
  #checkov:skip=CKV_AWS_356:SSM, SSMMessages, and EC2Messages actions in the AWS-managed AmazonSSMManagedInstanceCore policy use Resource "*" where resource-level restriction is not applicable.
  statement {
    effect = "Allow"

    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",

      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",

      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ec2_boundary" {
  count = var.enable_ec2_role ? 1 : 0

  name        = "${var.name}-ec2-permission-boundary"
  description = "Permission boundary for EC2 workloads."

  policy = data.aws_iam_policy_document.ec2_boundary.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-ec2-permission-boundary"
    }
  )
}

resource "aws_iam_role" "ec2" {
  count = var.enable_ec2_role ? 1 : 0

  name = "${var.name}-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  permissions_boundary = aws_iam_policy.ec2_boundary[0].arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-ec2-role"
      Tier = "compute"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  count = var.enable_ec2_role ? 1 : 0

  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.enable_ec2_role ? 1 : 0

  name = "${var.name}-ec2-profile"

  role = aws_iam_role.ec2[0].name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-ec2-profile"
      Tier = "compute"
    }
  )
}

data "aws_iam_policy_document" "auditor_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"

      identifiers = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

resource "aws_iam_role" "auditor" {
  count = var.enable_auditor_role ? 1 : 0

  name = "${var.name}-auditor-role"

  assume_role_policy = data.aws_iam_policy_document.auditor_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-auditor-role"
      Tier = "audit"
    }
  )
}

resource "aws_iam_role_policy_attachment" "auditor_read_only" {
  count = var.enable_auditor_role ? 1 : 0

  role       = aws_iam_role.auditor[0].name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "cicd_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "AWS"

      identifiers = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

resource "aws_iam_role" "cicd" {
  count = var.enable_cicd_role ? 1 : 0

  name = "${var.name}-cicd-role"

  assume_role_policy = data.aws_iam_policy_document.cicd_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-cicd-role"
      Tier = "cicd"
    }
  )
}

resource "aws_accessanalyzer_analyzer" "this" {
  count = var.enable_access_analyzer ? 1 : 0

  analyzer_name = "${var.name}-access-analyzer"

  type = "ACCOUNT"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.name}-access-analyzer"
      Tier = "security"
    }
  )
}
