# ========================================
# Outputs - Modular Version
# ========================================

# Frontend Outputs
output "frontend_alb_dns" {
  description = "Frontend ALB DNS name"
  value       = module.frontend_alb.alb_dns_name
}

output "frontend_alb_arn" {
  description = "Frontend ALB ARN"
  value       = module.frontend_alb.alb_arn
}

output "frontend_target_group_arn" {
  description = "Frontend target group ARN"
  value       = module.frontend_target_group.target_group_arn
}

output "frontend_domain" {
  description = "Frontend domain name"
  value       = module.frontend_dns.primary_fqdn
}

output "frontend_www_domain" {
  description = "Frontend www domain name"
  value       = module.frontend_dns.www_fqdn
}

# Backend Outputs
output "backend_alb_dns" {
  description = "Backend ALB DNS name"
  value       = module.backend_alb.alb_dns_name
}

output "backend_alb_arn" {
  description = "Backend ALB ARN"
  value       = module.backend_alb.alb_arn
}

output "backend_target_group_arn" {
  description = "Backend target group ARN"
  value       = module.backend_target_group.target_group_arn
}

output "backend_domain" {
  description = "Backend domain name"
  value       = module.backend_dns.primary_fqdn
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.alb_security_group.security_group_id
}

output "instances_security_group_id" {
  description = "Instances security group ID"
  value       = module.instances_security_group.security_group_id
}

# Target Instance Info
output "target_instance_ids" {
  description = "IDs of instances attached to target groups"
  value       = data.aws_instances.k8s_nodes.ids
}

output "target_instance_count" {
  description = "Number of instances attached to target groups"
  value       = length(data.aws_instances.k8s_nodes.ids)
}

# Connection Info
output "connection_info" {
  description = "Connection information for the MERN app"
  value = {
    frontend_url     = "https://${module.frontend_dns.primary_fqdn}"
    frontend_www_url = var.create_www_record ? "https://${module.frontend_dns.www_fqdn}" : null
    backend_url      = "https://${module.backend_dns.primary_fqdn}"
    backend_api_url  = "https://${module.backend_dns.primary_fqdn}/api"
  }
}
