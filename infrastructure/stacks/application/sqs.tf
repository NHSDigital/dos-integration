resource "aws_sqs_queue" "holding_queue" {
  name                        = var.holding_queue
  fifo_queue                  = true
  content_based_deduplication = true
  deduplication_scope         = "messageGroup"
  message_retention_seconds   = 1209600 # 14 days
  fifo_throughput_limit       = "perMessageGroupId"
  visibility_timeout_seconds  = 10 # Must be same as service matcher max execution time
  kms_master_key_id           = data.aws_kms_key.signing_key.key_id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.holding_queue_dlq.arn
    maxReceiveCount     = 5
  })
  depends_on = [aws_sqs_queue.holding_queue_dlq]
}

resource "aws_sqs_queue" "update_request_queue" {
  name                        = var.update_request_queue
  fifo_queue                  = true
  content_based_deduplication = true
  deduplication_scope         = "messageGroup"
  message_retention_seconds   = 1209600 # 14 days
  fifo_throughput_limit       = "perMessageGroupId"
  visibility_timeout_seconds  = 30 # Service sync max execution time
  kms_master_key_id           = data.aws_kms_key.signing_key.key_id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.update_request_dlq.arn
    maxReceiveCount     = 5
  })
  depends_on = [aws_sqs_queue.update_request_dlq]
}

resource "aws_lambda_event_source_mapping" "holding_queue_event_source_mapping" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.holding_queue.arn
  enabled          = true
  function_name    = module.service_matcher_lambda.lambda_function_arn

  lifecycle {
    ignore_changes = [ tags, tags_all ]
  }
}

resource "aws_lambda_event_source_mapping" "update_request_event_source_mapping" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.update_request_queue.arn
  enabled          = true
  function_name    = module.service_sync_lambda.lambda_function_arn

  lifecycle {
    ignore_changes = [ tags, tags_all ]
  }
}

resource "aws_sqs_queue" "holding_queue_dlq" {
  name                      = var.holding_queue_dlq
  fifo_queue                = true
  kms_master_key_id         = data.aws_kms_key.signing_key.key_id
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "update_request_dlq" {
  name                      = var.update_request_dlq
  fifo_queue                = true
  kms_master_key_id         = data.aws_kms_key.signing_key.key_id
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_lambda_event_source_mapping" "holding_queue_dlq_event_source_mapping" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.holding_queue_dlq.arn
  enabled          = true
  function_name    = module.change_event_dlq_handler_lambda.lambda_function_arn
  depends_on       = [aws_sqs_queue.holding_queue_dlq, module.change_event_dlq_handler_lambda]

  lifecycle {
    ignore_changes = [ tags, tags_all ]
  }
}

resource "aws_lambda_event_source_mapping" "update_request_dlq_event_source_mapping" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.update_request_dlq.arn
  enabled          = true
  function_name    = module.dos_db_update_dlq_handler_lambda.lambda_function_arn
  depends_on       = [aws_sqs_queue.update_request_dlq, module.dos_db_update_dlq_handler_lambda]

  lifecycle {
    ignore_changes = [ tags, tags_all ]
  }
}
