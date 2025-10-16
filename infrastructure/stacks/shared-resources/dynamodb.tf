resource "aws_dynamodb_table" "message-history-table" {
  name                        = var.change_events_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "Id"
  range_key                   = "ODSCode"
  deletion_protection_enabled = var.ddb_delete_protection

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.signing_key.arn
  }

  attribute {
    name = "Id"
    type = "S"
  }

  attribute {
    name = "ODSCode"
    type = "S"
  }

  attribute {
    name = "SequenceNumber"
    type = "N"
  }

  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  global_secondary_index {
    name            = "gsi_ods_sequence"
    hash_key        = "ODSCode"
    range_key       = "SequenceNumber"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    "backup_plan" = "none"
  }

  depends_on = [
    aws_kms_key.signing_key
  ]
}
