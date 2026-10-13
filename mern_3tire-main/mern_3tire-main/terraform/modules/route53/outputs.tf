output "zone_id" {
  description = "The Route53 zone ID"
  value       = data.aws_route53_zone.this.zone_id
}

output "primary_fqdn" {
  description = "The FQDN of the primary record"
  value       = aws_route53_record.primary.fqdn
}

output "www_fqdn" {
  description = "The FQDN of the www record"
  value       = var.create_www_record ? aws_route53_record.www[0].fqdn : null
}
