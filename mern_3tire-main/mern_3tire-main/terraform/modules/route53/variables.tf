variable "domain_name" {
  description = "Base domain name (e.g., example.com)"
  type        = string
}

variable "subdomain" {
  description = "Subdomain (empty for apex domain)"
  type        = string
  default     = ""
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "alb_zone_id" {
  description = "ALB zone ID"
  type        = string
}

variable "create_www_record" {
  description = "Create www subdomain record"
  type        = bool
  default     = false
}

variable "evaluate_target_health" {
  description = "Evaluate target health in Route53"
  type        = bool
  default     = true
}
