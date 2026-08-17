output "zone_id" {
  description = "Route 53 hosted zone ID."
  value       = aws_route53_zone.this.zone_id
}

output "zone_name" {
  description = "Route 53 hosted zone name."
  value       = aws_route53_zone.this.name
}

output "name_servers" {
  description = "Authoritative Route 53 name servers."
  value       = aws_route53_zone.this.name_servers
}

output "dev_record_name" {
  description = "DEV application DNS record."
  value       = var.dev_alb_dns_name != "" ? "dev.${var.domain_name}" : null
}
