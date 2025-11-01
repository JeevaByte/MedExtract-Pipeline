variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "medextract-pipeline"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "ses_email_domain" {
  description = "Domain for SES email receiving"
  type        = string
}

variable "db_master_username" {
  description = "Master username for Aurora PostgreSQL"
  type        = string
  default     = "medextract_admin"
  sensitive   = true
}

variable "db_master_password" {
  description = "Master password for Aurora PostgreSQL"
  type        = string
  sensitive   = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "MedExtract-Pipeline"
    ManagedBy   = "Terraform"
    Compliance  = "NHS-DSPT"
  }
}
