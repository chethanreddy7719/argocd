# ========================================
# MERN 3-Tier Application - ALB Infrastructure
# Uses child modules for ALB, Target Groups, Route53
# ========================================

# ========================================
# Data Sources
# ========================================

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get public subnets in VPC
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Get K8s node instances by tag
data "aws_instances" "k8s_nodes" {
  filter {
    name   = "tag:${var.target_instance_tag_key}"
    values = [var.target_instance_tag_value]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# ========================================
# Locals
# ========================================

locals {
  vpc_id            = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
  public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.aws_subnets.public.ids
}

# ========================================
# Security Groups
# ========================================

module "alb_security_group" {
  source = "./modules/security-group"

  project_name = var.project_name
  name         = "alb"
  description  = "Security group for ALBs - allows HTTP/HTTPS from internet"
  vpc_id       = local.vpc_id

  ingress_rules = [
    {
      description = "HTTP from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS from internet"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = {
    Component = "LoadBalancer"
  }
}

module "instances_security_group" {
  source = "./modules/security-group"

  project_name = var.project_name
  name         = "instances"
  description  = "Security group for K8s nodes - allows traffic from ALB"
  vpc_id       = local.vpc_id

  ingress_rules = [
    {
      description     = "NGINX Ingress NodePort from ALB"
      from_port       = var.ingress_nodeport
      to_port         = var.ingress_nodeport
      protocol        = "tcp"
      security_groups = [module.alb_security_group.security_group_id]
    },
    {
      description     = "Health check NodePort from ALB"
      from_port       = var.healthcheck_target_port
      to_port         = var.healthcheck_target_port
      protocol        = "tcp"
      security_groups = [module.alb_security_group.security_group_id]
    }
  ]

  tags = {
    Component = "K8sNodes"
  }
}

# ========================================
# Frontend Target Group
# ========================================

module "frontend_target_group" {
  source = "./modules/target-group"

  project_name = var.project_name
  name         = "frontend"
  vpc_id       = local.vpc_id
  port         = var.ingress_nodeport
  target_ids   = data.aws_instances.k8s_nodes.ids

  health_check_path     = var.health_check_path
  health_check_port     = tostring(var.healthcheck_target_port)
  health_check_interval = var.health_check_interval
  health_check_timeout  = var.health_check_timeout
  healthy_threshold     = var.healthy_threshold
  unhealthy_threshold   = var.unhealthy_threshold

  tags = {
    Component = "Frontend"
  }
}

# ========================================
# Frontend ALB
# ========================================

module "frontend_alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  name               = "frontend"
  security_group_ids = [module.alb_security_group.security_group_id]
  subnet_ids         = local.public_subnet_ids
  certificate_arn    = var.frontend_certificate_arn
  target_group_arn   = module.frontend_target_group.target_group_arn

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  tags = {
    Component = "Frontend"
  }
}

# ========================================
# Backend Target Group
# ========================================

module "backend_target_group" {
  source = "./modules/target-group"

  project_name = var.project_name
  name         = "backend"
  vpc_id       = local.vpc_id
  port         = var.ingress_nodeport
  target_ids   = data.aws_instances.k8s_nodes.ids

  health_check_path     = "/healthz"
  health_check_port     = tostring(var.healthcheck_target_port)
  health_check_interval = var.health_check_interval
  health_check_timeout  = var.health_check_timeout
  healthy_threshold     = var.healthy_threshold
  unhealthy_threshold   = var.unhealthy_threshold

  tags = {
    Component = "Backend"
  }
}

# ========================================
# Backend ALB
# ========================================

module "backend_alb" {
  source = "./modules/alb"

  project_name       = var.project_name
  name               = "backend"
  security_group_ids = [module.alb_security_group.security_group_id]
  subnet_ids         = local.public_subnet_ids
  certificate_arn    = var.backend_certificate_arn
  target_group_arn   = module.backend_target_group.target_group_arn

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  tags = {
    Component = "Backend"
  }
}

# ========================================
# Route53 Records - Frontend
# ========================================

module "frontend_dns" {
  source = "./modules/route53"

  domain_name       = var.domain_name
  subdomain         = var.frontend_subdomain
  alb_dns_name      = module.frontend_alb.alb_dns_name
  alb_zone_id       = module.frontend_alb.alb_zone_id
  create_www_record = var.create_www_record
}

# ========================================
# Route53 Records - Backend
# ========================================

module "backend_dns" {
  source = "./modules/route53"

  domain_name       = var.domain_name
  subdomain         = var.backend_subdomain
  alb_dns_name      = module.backend_alb.alb_dns_name
  alb_zone_id       = module.backend_alb.alb_zone_id
  create_www_record = false
}

# ========================================
# Attach Instance Security Group to K8s Nodes
# ========================================

resource "null_resource" "attach_sg_to_instances" {
  count = length(data.aws_instances.k8s_nodes.ids) > 0 ? 1 : 0

  triggers = {
    instance_ids        = join(",", data.aws_instances.k8s_nodes.ids)
    sg_id               = module.instances_security_group.security_group_id
    frontend_tg_arn     = module.frontend_target_group.target_group_arn
    backend_tg_arn      = module.backend_target_group.target_group_arn
    ingress_nodeport    = var.ingress_nodeport
  }

  provisioner "local-exec" {
    command = <<-EOT
      for instance_id in ${join(" ", data.aws_instances.k8s_nodes.ids)}; do
        current_sgs=$(aws ec2 describe-instances \
          --instance-ids $instance_id \
          --region ${var.aws_region} \
          --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
          --output text)
        
        if ! echo "$current_sgs" | grep -q "${module.instances_security_group.security_group_id}"; then
          all_sgs="$current_sgs ${module.instances_security_group.security_group_id}"
          aws ec2 modify-instance-attribute \
            --instance-id $instance_id \
            --region ${var.aws_region} \
            --groups $all_sgs
          echo "Attached security group to instance $instance_id"
        else
          echo "Security group already attached to instance $instance_id"
        fi
      done
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Starting cleanup of Terraform-managed resources ==="
      
      # Step 1: Deregister instances from target groups
      echo "Step 1: Deregistering instances from target groups..."
      for instance_id in ${join(" ", split(",", self.triggers.instance_ids))}; do
        # Deregister from frontend target group
        aws elbv2 deregister-targets \
          --target-group-arn ${self.triggers.frontend_tg_arn} \
          --targets Id=$instance_id,Port=${self.triggers.ingress_nodeport} \
          --region ${var.aws_region} 2>/dev/null || echo "Instance $instance_id already deregistered from frontend TG"
        
        # Deregister from backend target group
        aws elbv2 deregister-targets \
          --target-group-arn ${self.triggers.backend_tg_arn} \
          --targets Id=$instance_id,Port=${self.triggers.ingress_nodeport} \
          --region ${var.aws_region} 2>/dev/null || echo "Instance $instance_id already deregistered from backend TG"
      done
      
      echo "Waiting 10 seconds for target deregistration to complete..."
      sleep 10
      
      # Step 2: Detach security group from instances
      echo "Step 2: Detaching security group from instances..."
      for instance_id in ${join(" ", split(",", self.triggers.instance_ids))}; do
        current_sgs=$(aws ec2 describe-instances \
          --instance-ids $instance_id \
          --region ${var.aws_region} \
          --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
          --output text 2>/dev/null)
        
        # Remove the managed security group from the list
        new_sgs=$(echo "$current_sgs" | tr '\t' '\n' | grep -v "${self.triggers.sg_id}" | tr '\n' ' ')
        
        if [ -n "$new_sgs" ]; then
          aws ec2 modify-instance-attribute \
            --instance-id $instance_id \
            --region ${var.aws_region} \
            --groups $new_sgs
          echo "Detached security group from instance $instance_id"
        else
          echo "Warning: No security groups left for instance $instance_id after removal"
        fi
      done
      
      echo "=== Cleanup complete. EC2 instances preserved. ==="
    EOT
  }
}
