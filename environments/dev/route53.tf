# ==================================================
# Route 53 - Dev Application DNS
# ==================================================

data "aws_route53_zone" "main" {
  name         = "muralidharops.com."
  private_zone = false
}

resource "aws_route53_record" "dev" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "dev.muralidharops.com"
  type    = "A"

  alias {
    name                   = module.compute.alb_dns_name
    zone_id                = module.compute.alb_zone_id
    evaluate_target_health = true
  }
}
