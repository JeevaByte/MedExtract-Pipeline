variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "kms_key_arn" {
  type = string
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_rds_cluster" "postgres" {
  cluster_identifier      = "${var.project_name}-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.4"
  database_name           = "medextract"
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = var.security_group_ids
  storage_encrypted       = true
  kms_key_id              = var.kms_key_arn
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = true
  
  serverlessv2_scaling_configuration {
    max_capacity = 2.0
    min_capacity = 0.5
  }
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  tags = {
    Name = "${var.project_name}-postgres-cluster"
  }
}

resource "aws_rds_cluster_instance" "postgres" {
  identifier              = "${var.project_name}-instance-1"
  cluster_identifier      = aws_rds_cluster.postgres.id
  instance_class          = "db.serverless"
  engine                  = aws_rds_cluster.postgres.engine
  engine_version          = aws_rds_cluster.postgres.engine_version
  publicly_accessible     = false
  performance_insights_enabled = true
}

output "cluster_endpoint" {
  value     = aws_rds_cluster.postgres.endpoint
  sensitive = true
}

output "cluster_reader_endpoint" {
  value     = aws_rds_cluster.postgres.reader_endpoint
  sensitive = true
}

output "database_name" {
  value = aws_rds_cluster.postgres.database_name
}

output "cluster_arn" {
  value = aws_rds_cluster.postgres.arn
}
