terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Configure backend in terraform.tfvars or via CLI
    # bucket = "medextract-terraform-state"
    # key    = "medextract-pipeline/terraform.tfstate"
    # region = "us-east-1"
    # encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.tags
  }
}

# KMS Key for encryption
resource "aws_kms_key" "medextract" {
  description             = "KMS key for MedExtract Pipeline encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "medextract" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.medextract.key_id
}

data "aws_caller_identity" "current" {}

# VPC for Lambda and RDS
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"
  
  tags = {
    Name = "${var.project_name}-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = "${var.aws_region}b"
  
  tags = {
    Name = "${var.project_name}-private-b"
  }
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }
  
  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Modules
module "s3_kms" {
  source = "./modules/s3-kms"
  
  project_name = var.project_name
  environment  = var.environment
  kms_key_arn  = aws_kms_key.medextract.arn
}

module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "./modules/rds"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = aws_vpc.main.id
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.rds.id]
  db_username        = var.db_master_username
  db_password        = var.db_master_password
  kms_key_arn        = aws_kms_key.medextract.arn
}

module "lambda" {
  source = "./modules/lambda"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = aws_vpc.main.id
  subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids = [aws_security_group.lambda.id]
  s3_bucket_arn      = module.s3_kms.bucket_arn
  dynamodb_table_arn = module.dynamodb.table_arn
  rds_endpoint       = module.rds.cluster_endpoint
  kms_key_arn        = aws_kms_key.medextract.arn
}

module "ses" {
  source = "./modules/ses"
  
  project_name      = var.project_name
  environment       = var.environment
  email_domain      = var.ses_email_domain
  s3_bucket_name    = module.s3_kms.bucket_name
  lambda_invoke_arn = module.lambda.ses_handler_invoke_arn
}

# CloudTrail for audit logging
resource "aws_cloudtrail" "medextract" {
  count = var.enable_cloudtrail ? 1 : 0
  
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = module.s3_kms.cloudtrail_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${module.s3_kms.bucket_arn}/*"]
    }
  }
  
  depends_on = [module.s3_kms]
}

# CloudWatch Log Group for centralized logging
resource "aws_cloudwatch_log_group" "medextract" {
  name              = "/aws/medextract/${var.environment}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.medextract.arn
}
