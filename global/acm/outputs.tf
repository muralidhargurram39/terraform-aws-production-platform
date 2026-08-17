output "certificate_arn" {
  description = "Issued ACM certificate ARN."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "certificate_domain" {
  description = "Primary domain covered by the certificate."
  value       = aws_acm_certificate.this.domain_name
}

output "certificate_status" {
  description = "ACM certificate status."
  value       = aws_acm_certificate.this.status
}

output "validation_record_fqdns" {
  description = "DNS validation record FQDNs."
  value = [
    for record in aws_route53_record.validation : record.fqdn
  ]
}
