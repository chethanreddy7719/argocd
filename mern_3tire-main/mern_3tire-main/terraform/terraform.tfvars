# ========================================
# AWS Configuration
# ========================================
aws_region   = "ap-south-1"
project_name = "mern-3tier"
environment  = "production"

# ========================================
# Domain Configuration
# ========================================
domain_name         = "acadcart.com"
frontend_subdomain  = ""           # Empty for apex domain (acadcart.com)
backend_subdomain   = "backend"    # backend.acadcart.com
create_www_record   = true         # Create www.acadcart.com

# ========================================
# Network Configuration (Optional - uses default VPC if not specified)
# ========================================
# vpc_id             = "vpc-0123456789abcdef0"
# public_subnet_ids  = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]

# ========================================
# ALB Configuration
# ========================================
frontend_certificate_arn   = "arn:aws:acm:ap-south-1:637423622313:certificate/e1cb85a2-2330-47f8-9505-6191cb06a630"  # acadcart.com
backend_certificate_arn    = "arn:aws:acm:ap-south-1:637423622313:certificate/7b5d1275-1254-4487-ae00-07fe6962b2d6"  # backend.acadcart.com
# alb_security_group_ids   = ["sg-0123456789abcdef0"]  # Optional: Leave commented to auto-create
enable_deletion_protection = false
idle_timeout               = 60

# ========================================
# Target Configuration
# ========================================
target_instance_tag_key    = "k8s"
target_instance_tag_value  = "prod"
ingress_nodeport           = 32580  # NGINX Ingress Controller NodePort
healthcheck_target_port    = 30080  # NodePort for health checks

# ========================================
# Health Check Configuration
# ========================================
health_check_path      = "/healthz"
health_check_interval  = 30
health_check_timeout   = 5
healthy_threshold      = 2
unhealthy_threshold    = 2
ttl                    = 300
