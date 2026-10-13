# MERN 3-Tier Terraform Modules

This directory contains modularized Terraform code for deploying ALB infrastructure for the MERN 3-tier application.

## Module Structure

```
terraform/
├── main.tf              # Original monolithic configuration
├── main-modular.tf      # New modular configuration (use this)
├── outputs-modular.tf   # Outputs for modular configuration
├── variables.tf         # Input variables
├── terraform.tfvars     # Variable values
├── provider.tf          # Provider configuration
└── modules/
    ├── alb/             # Application Load Balancer module
    ├── target-group/    # Target Group module
    ├── security-group/  # Security Group module
    └── route53/         # Route53 DNS module
```

## Usage

### 1. Switch to Modular Configuration

Rename or remove the old `main.tf` and `outputs.tf`:

```bash
mv main.tf main.tf.backup
mv outputs.tf outputs.tf.backup
mv main-modular.tf main.tf
mv outputs-modular.tf outputs.tf
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Apply the Configuration

```bash
terraform apply
```

## Modules

### ALB Module (`modules/alb`)

Creates an Application Load Balancer with HTTP to HTTPS redirect.

**Inputs:**
- `project_name` - Project name for naming
- `name` - ALB name suffix (frontend/backend)
- `security_group_ids` - List of security group IDs
- `subnet_ids` - List of subnet IDs
- `certificate_arn` - ACM certificate ARN
- `target_group_arn` - Target group ARN

**Outputs:**
- `alb_dns_name` - ALB DNS name
- `alb_zone_id` - ALB zone ID for Route53

### Target Group Module (`modules/target-group`)

Creates a target group and attaches instances.

**Inputs:**
- `project_name` - Project name
- `name` - Target group name suffix
- `vpc_id` - VPC ID
- `port` - Target port (default: 80)
- `target_ids` - List of instance IDs
- `health_check_*` - Health check configuration

**Outputs:**
- `target_group_arn` - Target group ARN

### Security Group Module (`modules/security-group`)

Creates security groups with dynamic ingress rules.

**Inputs:**
- `project_name` - Project name
- `name` - Security group name suffix
- `vpc_id` - VPC ID
- `ingress_rules` - List of ingress rule objects

**Outputs:**
- `security_group_id` - Security group ID

### Route53 Module (`modules/route53`)

Creates Route53 alias records pointing to ALB.

**Inputs:**
- `domain_name` - Base domain (e.g., acadcart.com)
- `subdomain` - Subdomain (empty for apex)
- `alb_dns_name` - ALB DNS name
- `alb_zone_id` - ALB zone ID
- `create_www_record` - Create www subdomain

**Outputs:**
- `primary_fqdn` - Primary record FQDN
- `www_fqdn` - WWW record FQDN

## Architecture

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                        Route53                              │
                    │   acadcart.com    www.acadcart.com    backend.acadcart.com  │
                    └──────────┬─────────────────┬──────────────────┬─────────────┘
                               │                 │                  │
                    ┌──────────▼─────────────────▼──────────────────▼─────────────┐
                    │                    ALB (HTTPS)                              │
                    │         Frontend ALB              Backend ALB               │
                    └──────────┬─────────────────────────────┬───────────────────┘
                               │                             │
                    ┌──────────▼─────────────────────────────▼───────────────────┐
                    │              Target Groups (Port 80)                        │
                    │    frontend-tg                    backend-tg                │
                    └──────────┬─────────────────────────────┬───────────────────┘
                               │                             │
                    ┌──────────▼─────────────────────────────▼───────────────────┐
                    │              K8s Worker Nodes                               │
                    │        NGINX Ingress Controller (Port 80)                   │
                    │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
                    │  │   Node 1    │  │   Node 2    │  │   Node 3    │          │
                    │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
                    └─────────┴────────────────┴────────────────┴─────────────────┘
                                               │
                    ┌──────────────────────────▼──────────────────────────────────┐
                    │                    K8s Services                              │
                    │         frontend-svc              backend-svc                │
                    │         (Ingress routes)          (Ingress routes)           │
                    └─────────────────────────────────────────────────────────────┘
```

## Required for MERN App

Your Kubernetes Ingress should be configured to route:

1. **Frontend**: `acadcart.com` and `www.acadcart.com` → frontend service
2. **Backend**: `backend.acadcart.com` → backend service

Example Ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: acadcart.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```
