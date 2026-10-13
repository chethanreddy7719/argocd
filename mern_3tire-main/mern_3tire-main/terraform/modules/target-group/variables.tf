variable "project_name" {
  description = "Project name for naming resources"
  type        = string
}

variable "name" {
  description = "Name suffix for the target group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "port" {
  description = "Port for the target group"
  type        = number
  default     = 80
}

variable "protocol" {
  description = "Protocol for the target group"
  type        = string
  default     = "HTTP"
}

variable "target_ids" {
  description = "List of target instance IDs"
  type        = list(string)
  default     = []
}

# Health check variables
variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "Health check port"
  type        = string
  default     = "traffic-port"
}

variable "health_check_protocol" {
  description = "Health check protocol"
  type        = string
  default     = "HTTP"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Healthy threshold count"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Unhealthy threshold count"
  type        = number
  default     = 2
}

variable "health_check_matcher" {
  description = "Health check matcher codes"
  type        = string
  default     = "200-399"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
