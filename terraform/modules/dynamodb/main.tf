variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

resource "aws_dynamodb_table" "ontology_mapping" {
  name           = "${var.project_name}-ontology-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "entity_text"
  range_key      = "entity_type"
  
  attribute {
    name = "entity_text"
    type = "S"
  }
  
  attribute {
    name = "entity_type"
    type = "S"
  }
  
  attribute {
    name = "icd10_code"
    type = "S"
  }
  
  attribute {
    name = "snomed_code"
    type = "S"
  }
  
  global_secondary_index {
    name            = "icd10-index"
    hash_key        = "icd10_code"
    projection_type = "ALL"
  }
  
  global_secondary_index {
    name            = "snomed-index"
    hash_key        = "snomed_code"
    projection_type = "ALL"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Name = "${var.project_name}-ontology"
  }
}

output "table_name" {
  value = aws_dynamodb_table.ontology_mapping.name
}

output "table_arn" {
  value = aws_dynamodb_table.ontology_mapping.arn
}
