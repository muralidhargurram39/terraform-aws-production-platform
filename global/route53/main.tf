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

resource "aws_route53_record" "dev" {
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
