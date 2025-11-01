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

variable "s3_bucket_arn" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "rds_endpoint" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${var.project_name}-lambda-permissions"
  role = aws_iam_role.lambda_exec.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "comprehendmedical:DetectEntitiesV2",
          "comprehendmedical:DetectPHI",
          "comprehendmedical:InferICD10CM",
          "comprehendmedical:InferRxNorm",
          "comprehendmedical:InferSNOMEDCT"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:AnalyzeDocument"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# SES Ingest Handler Lambda
resource "aws_lambda_function" "ses_ingest_handler" {
  filename         = "${path.module}/../../../lambda/ses_ingest_handler/deployment.zip"
  function_name    = "${var.project_name}-ses-ingest"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512
  
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
  
  environment {
    variables = {
      S3_BUCKET    = split(":", var.s3_bucket_arn)[5]
      ENVIRONMENT  = var.environment
    }
  }
}

# Attachment Parser Lambda
resource "aws_lambda_function" "attachment_parser" {
  filename         = "${path.module}/../../../lambda/attachment_parser/deployment.zip"
  function_name    = "${var.project_name}-parser"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "parser.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 1024
  
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
  
  environment {
    variables = {
      S3_BUCKET = split(":", var.s3_bucket_arn)[5]
    }
  }
}

# Comprehend Worker Lambda
resource "aws_lambda_function" "comprehend_worker" {
  filename         = "${path.module}/../../../lambda/comprehend_worker/deployment.zip"
  function_name    = "${var.project_name}-comprehend"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "worker.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 1024
  
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
}

# Ontology Mapper Lambda
resource "aws_lambda_function" "ontology_mapper" {
  filename         = "${path.module}/../../../lambda/ontology_mapper/deployment.zip"
  function_name    = "${var.project_name}-mapper"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "mapper.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512
  
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
  
  environment {
    variables = {
      DYNAMODB_TABLE = split("/", var.dynamodb_table_arn)[1]
    }
  }
}

# Postgres Loader Lambda
resource "aws_lambda_function" "postgres_loader" {
  filename         = "${path.module}/../../../lambda/loader/deployment.zip"
  function_name    = "${var.project_name}-loader"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "load_to_postgres.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 1024
  
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }
  
  environment {
    variables = {
      DB_ENDPOINT = var.rds_endpoint
      DB_NAME     = "medextract"
    }
  }
}

# Lambda permission for SES
resource "aws_lambda_permission" "ses_invoke" {
  statement_id  = "AllowExecutionFromSES"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ses_ingest_handler.function_name
  principal     = "ses.amazonaws.com"
}

output "ses_handler_arn" {
  value = aws_lambda_function.ses_ingest_handler.arn
}

output "ses_handler_invoke_arn" {
  value = aws_lambda_function.ses_ingest_handler.invoke_arn
}

output "parser_arn" {
  value = aws_lambda_function.attachment_parser.arn
}

output "comprehend_arn" {
  value = aws_lambda_function.comprehend_worker.arn
}

output "mapper_arn" {
  value = aws_lambda_function.ontology_mapper.arn
}

output "loader_arn" {
  value = aws_lambda_function.postgres_loader.arn
}
