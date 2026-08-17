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

resource "aws_route53_zone" "this" {
  name = var.domain_name

  comment = "Public hosted zone for ${var.domain_name}"

  tags = local.common_tags
}
