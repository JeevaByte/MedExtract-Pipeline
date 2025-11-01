variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "email_domain" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "lambda_invoke_arn" {
  type = string
}

resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "${var.project_name}-rule-set"
}

resource "aws_ses_active_receipt_rule_set" "main" {
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
}

resource "aws_ses_receipt_rule" "store_email" {
  name          = "${var.project_name}-store-and-process"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  enabled       = true
  scan_enabled  = true
  tls_policy    = "Require"
  
  recipients = ["referrals@${var.email_domain}"]
  
  s3_action {
    bucket_name       = var.s3_bucket_name
    object_key_prefix = "incoming/"
    position          = 1
  }
  
  lambda_action {
    function_arn    = var.lambda_invoke_arn
    invocation_type = "Event"
    position        = 2
  }
}

# SES domain identity (needs manual verification)
resource "aws_ses_domain_identity" "main" {
  domain = var.email_domain
}

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

output "rule_set_name" {
  value = aws_ses_receipt_rule_set.main.rule_set_name
}

output "domain_identity_arn" {
  value = aws_ses_domain_identity.main.arn
}

output "dkim_tokens" {
  value       = aws_ses_domain_dkim.main.dkim_tokens
  description = "DKIM tokens for DNS configuration"
}
