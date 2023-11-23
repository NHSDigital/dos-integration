data "aws_iam_policy_document" "change_event_dlq_handler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.change_event_dlq}",
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.holding_queue_dlq}",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*/index/gsi_ods_sequence",
    ]
  }
}

data "aws_iam_policy_document" "dos_db_handler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:*",
    ]
  }
}

data "aws_iam_policy_document" "dos_db_update_dlq_handler_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.update_request_dlq}",
    ]
  }
}

data "aws_iam_policy_document" "event_replay_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueUrl",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.project_id}*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*/index/gsi_ods_sequence",
    ]
  }
}

data "aws_iam_policy_document" "ingest_change_event_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.change_event_queue}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.holding_queue}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*/index/gsi_ods_sequence",
    ]
  }
}

data "aws_iam_policy_document" "quality_checker_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:*",
    ]
  }
}

data "aws_iam_policy_document" "send_email_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::${var.send_email_bucket_name}",
      "arn:aws:s3:::${var.send_email_bucket_name}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:uec-dos-int-*",
    ]
  }
}

data "aws_iam_policy_document" "service_matcher_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.holding_queue}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:SendMessageBatch",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.update_request_queue}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
}

data "aws_iam_policy_document" "service_sync_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.update_request_dlq}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
    ]
    resources = [
      "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.update_request_queue}",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:Query",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.project_id}*/index/gsi_ods_sequence",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${var.send_email_bucket_name}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.send_email_lambda}",
    ]
  }
}

data "aws_iam_policy_document" "slack_messenger_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = [
      data.aws_kms_key.signing_key.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sns:*",
    ]
    resources = [
      "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.project_id}-*",
      "arn:aws:sns:${var.route53_health_check_alarm_region}:${var.aws_account_id}:${var.project_id}-*",
    ]
  }
}
