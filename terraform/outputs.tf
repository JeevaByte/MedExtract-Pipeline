output "s3_bucket_name" {
  description = "Name of the S3 bucket for email storage"
  value       = module.s3_kms.bucket_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB ontology mapping table"
  value       = module.dynamodb.table_name
}

output "rds_cluster_endpoint" {
  description = "Aurora PostgreSQL cluster endpoint"
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "Database name in Aurora PostgreSQL"
  value       = module.rds.database_name
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.medextract.id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.medextract.arn
}

output "lambda_functions" {
  description = "Lambda function ARNs"
  value = {
    ses_ingest_handler  = module.lambda.ses_handler_arn
    attachment_parser   = module.lambda.parser_arn
    comprehend_worker   = module.lambda.comprehend_arn
    ontology_mapper     = module.lambda.mapper_arn
    postgres_loader     = module.lambda.loader_arn
  }
}

output "ses_receipt_rule_set" {
  description = "SES receipt rule set name"
  value       = module.ses.rule_set_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.medextract.name
}
