# ========================================
# Route53 Module
# ========================================

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

# Primary record (apex or subdomain)
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.subdomain == "" ? var.domain_name : "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}

# WWW record (optional)
resource "aws_route53_record" "www" {
  count   = var.create_www_record ? 1 : 0
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}
