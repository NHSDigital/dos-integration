module "change_event_dlq_handler_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.change_event_dlq_handler_lambda
  description   = "Change Event DLQ Handler lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.change_event_dlq_handler}:${var.change_event_dlq_handler_version}"
  package_type           = "Image"
  timeout                = 30
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.change_event_dlq_handler_lambda}-role"
  role_description = "Role for Lambda function ${var.change_event_dlq_handler_lambda}"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.change_event_dlq_handler_policy.json

  environment_variables = {
    "PROFILE"                            = var.profile,
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.change_event_dlq_handler_version
    "CHANGE_EVENTS_TABLE_NAME"           = var.change_events_table_name
  }
}

module "dos_db_handler_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.dos_db_handler_lambda
  description   = "DoS DB Handler lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.dos_db_handler}:${var.dos_db_handler_version}"
  package_type           = "Image"
  timeout                = 30
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.dos_db_handler_lambda}-role"
  role_description = "Role for Lambda function ${var.dos_db_handler_lambda}"

  attach_policy_json    = true
  policy_json           = data.aws_iam_policy_document.dos_db_handler_policy.json
  attach_network_policy = true

  vpc_subnet_ids         = data.aws_subnets.texas_vpc_private_subnets.ids
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]

  environment_variables = {
    "PROFILE"                            = var.profile,
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.dos_db_handler_version
    "DB_NAME"                            = var.dos_db_name
    "DB_PORT"                            = var.dos_db_port
    "DB_READ_ONLY_USER_NAME"             = local.dos_db_read_only_user_name
    "DB_READER_SECRET_NAME"              = var.dos_db_reader_secret_name
    "DB_READER_SECRET_KEY"               = var.dos_db_reader_secret_key
    "DB_READER_SERVER"                   = var.dos_db_reader_route_53
    "DB_WRITER_SERVER"                   = var.dos_db_writer_route_53
    "DB_SCHEMA"                          = var.dos_db_schema
    "DB_WRITER_SECRET_NAME"              = var.dos_db_writer_secret_name
    "DB_WRITER_SECRET_KEY"               = var.dos_db_writer_secret_key
    "DB_READ_AND_WRITE_USER_NAME"        = local.dos_db_read_and_write_user_name
  }
}

module "dos_db_update_dlq_handler_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.dos_db_update_dlq_handler_lambda
  description   = "DoS DB Update DLQ Handler lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.dos_db_update_dlq_handler}:${var.dos_db_update_dlq_handler_version}"
  package_type           = "Image"
  timeout                = 30
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.dos_db_update_dlq_handler_lambda}-role"
  role_description = "Role for Lambda function ${var.dos_db_update_dlq_handler_lambda}"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.dos_db_update_dlq_handler_policy.json

  environment_variables = {
    "PROFILE"                            = var.profile,
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.dos_db_update_dlq_handler_version
  }
}

module "event_replay_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.event_replay_lambda
  description   = "Event Replay lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.event_replay}:${var.event_replay_version}"
  package_type           = "Image"
  timeout                = 30
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.event_replay_lambda}-role"
  role_description = "Role for Lambda function ${var.event_replay_lambda}"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.event_replay_policy.json

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.event_replay_version
    "CHANGE_EVENTS_TABLE_NAME"           = var.change_events_table_name
    "CHANGE_EVENT_SQS_URL"               = data.aws_sqs_queue.change_event_queue.url
  }
}


module "ingest_change_event_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.ingest_change_event_lambda
  description   = "Ingest Change Event lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.ingest_change_event}:${var.ingest_change_event_version}"
  package_type           = "Image"
  timeout                = 30
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.ingest_change_event_lambda}-role"
  role_description = "Role for Lambda function ${var.ingest_change_event_lambda}"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.ingest_change_event_policy.json

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.ingest_change_event_version
    "CHANGE_EVENTS_TABLE_NAME"           = var.change_events_table_name
    "HOLDING_QUEUE_URL"                  = aws_sqs_queue.holding_queue.url
  }
}

module "send_email_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.send_email_lambda
  description   = "Send Email lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.send_email}:${var.send_email_version}"
  package_type           = "Image"
  timeout                = 30
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 2

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.send_email_lambda}-role"
  role_description = "Role for Lambda function ${var.send_email_lambda}"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.send_email_policy.json

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.send_email_version
    "AWS_ACCOUNT_NAME"                   = var.aws_account_name
    "SYSTEM_EMAIL_ADDRESS"               = local.project_system_email_address
    "EMAIL_SECRET_NAME"                  = var.project_deployment_secrets
  }
}

module "service_matcher_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.service_matcher_lambda
  description   = "Service Matcher lambda"

  create_package                 = false
  image_uri                      = "${var.docker_registry}/${var.service_matcher}:${var.service_matcher_version}"
  package_type                   = "Image"
  timeout                        = 10
  memory_size                    = 192
  architectures                  = ["arm64"]
  kms_key_arn                    = data.aws_kms_key.signing_key.arn
  tracing_mode                   = "Active"
  maximum_retry_attempts         = 0
  reserved_concurrent_executions = var.service_matcher_max_concurrency

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.service_matcher_lambda}-role"
  role_description = "Role for Lambda function ${var.service_matcher_lambda}"

  attach_policy_json    = true
  policy_json           = data.aws_iam_policy_document.service_matcher_policy.json
  attach_network_policy = true

  vpc_subnet_ids         = data.aws_subnets.texas_vpc_private_subnets.ids
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.service_matcher_version
    "UPDATE_REQUEST_QUEUE_URL"           = aws_sqs_queue.update_request_queue.url
    "DB_NAME"                            = var.dos_db_name
    "DB_PORT"                            = var.dos_db_port
    "DB_READ_ONLY_USER_NAME"             = local.dos_db_read_only_user_name
    "DB_READER_SECRET_NAME"              = var.dos_db_reader_secret_name
    "DB_READER_SECRET_KEY"               = var.dos_db_reader_secret_key
    "DB_READER_SERVER"                   = var.dos_db_reader_route_53
    "DB_WRITER_SERVER"                   = var.dos_db_writer_route_53
    "DB_SCHEMA"                          = var.dos_db_schema
  }
}

module "service_sync_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.service_sync_lambda
  description   = "Service Sync lambda"

  create_package                 = false
  image_uri                      = "${var.docker_registry}/${var.service_sync}:${var.service_sync_version}"
  package_type                   = "Image"
  timeout                        = 20
  memory_size                    = 512
  architectures                  = ["arm64"]
  kms_key_arn                    = data.aws_kms_key.signing_key.arn
  tracing_mode                   = "Active"
  maximum_retry_attempts         = 0
  reserved_concurrent_executions = var.service_sync_max_concurrency

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.service_sync_lambda}-role"
  role_description = "Role for Lambda function ${var.service_sync_lambda}"

  attach_policy_json    = true
  policy_json           = data.aws_iam_policy_document.service_sync_policy.json
  attach_network_policy = true

  vpc_subnet_ids         = data.aws_subnets.texas_vpc_private_subnets.ids
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.service_sync_version
    "UPDATE_REQUEST_QUEUE_URL"           = aws_sqs_queue.update_request_queue.url
    "DB_NAME"                            = var.dos_db_name
    "DB_PORT"                            = var.dos_db_port
    "DB_READ_ONLY_USER_NAME"             = local.dos_db_read_only_user_name
    "DB_READER_SECRET_NAME"              = var.dos_db_reader_secret_name
    "DB_READER_SECRET_KEY"               = var.dos_db_reader_secret_key
    "DB_READER_SERVER"                   = var.dos_db_reader_route_53
    "DB_WRITER_SERVER"                   = var.dos_db_writer_route_53
    "DB_SCHEMA"                          = var.dos_db_schema
    "DB_WRITER_SECRET_NAME"              = var.dos_db_writer_secret_name
    "DB_WRITER_SECRET_KEY"               = var.dos_db_writer_secret_key
    "DB_READ_AND_WRITE_USER_NAME"        = local.dos_db_read_and_write_user_name
    "SEND_EMAIL_BUCKET_NAME"             = var.send_email_bucket_name
    "TEAM_EMAIL_ADDRESS"                 = local.project_team_email_address
    "SYSTEM_EMAIL_ADDRESS"               = local.project_system_email_address
    "SEND_EMAIL_LAMBDA_NAME"             = var.send_email_lambda
  }
}

module "slack_messenger_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.slack_messenger_lambda
  description   = "Slack Messenger lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.slack_messenger}:${var.slack_messenger_version}"
  package_type           = "Image"
  timeout                = 10
  memory_size            = 128
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.slack_messenger_lambda}-role"
  role_description = "Role for Lambda function ${var.slack_messenger_lambda}"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.slack_messenger_policy.json

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.slack_messenger_version
    "SLACK_ALERT_CHANNEL"                = var.slack_alert_channel
    "SLACK_WEBHOOK_URL"                  = local.slack_webhook_url
  }
}

module "quality_checker_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.1.0"

  function_name = var.quality_checker_lambda
  description   = "Quality Checker lambda"

  create_package         = false
  image_uri              = "${var.docker_registry}/${var.quality_checker}:${var.quality_checker_version}"
  package_type           = "Image"
  timeout                = 900
  memory_size            = 512
  architectures          = ["arm64"]
  kms_key_arn            = data.aws_kms_key.signing_key.arn
  tracing_mode           = "Active"
  maximum_retry_attempts = 0

  cloudwatch_logs_kms_key_id        = data.aws_kms_key.signing_key.arn
  cloudwatch_logs_retention_in_days = 30

  role_name        = "${var.quality_checker_lambda}-role"
  role_description = "Role for Lambda function ${var.quality_checker_lambda}"

  attach_policy_json    = true
  policy_json           = data.aws_iam_policy_document.quality_checker_policy.json
  attach_network_policy = true

  vpc_subnet_ids         = data.aws_subnets.texas_vpc_private_subnets.ids
  vpc_security_group_ids = [aws_security_group.lambda_sg.id]

  environment_variables = {
    "PROFILE"                            = var.profile
    "ENVIRONMENT"                        = var.blue_green_environment
    "SHARED_ENVIRONMENT"                 = var.shared_environment
    "POWERTOOLS_SERVICE_NAME"            = var.lambda_powertools_service_name
    "POWERTOOLS_TRACER_CAPTURE_RESPONSE" = true
    "POWERTOOLS_TRACER_CAPTURE_ERROR"    = true
    "POWERTOOLS_TRACE_MIDDLEWARES"       = true
    "LOG_LEVEL"                          = var.log_level
    "IMAGE_VERSION"                      = var.quality_checker_version
    "DB_NAME"                            = var.dos_db_name
    "DB_PORT"                            = var.dos_db_port
    "DB_READ_ONLY_USER_NAME"             = local.dos_db_read_only_user_name
    "DB_READER_SECRET_NAME"              = var.dos_db_reader_secret_name
    "DB_READER_SECRET_KEY"               = var.dos_db_reader_secret_key
    "DB_READER_SERVER"                   = var.dos_db_reader_route_53
    "DB_WRITER_SERVER"                   = var.dos_db_writer_route_53
    "DB_SCHEMA"                          = var.dos_db_schema
    "ODSCODE_STARTING_CHARACTER"         = var.odscode_starting_character
  }
}

resource "aws_lambda_permission" "quality_checker_lambda" {
  action         = "lambda:InvokeFunction"
  function_name  = module.quality_checker_lambda.lambda_function_name
  principal      = "events.amazonaws.com"
  source_account = var.aws_account_id
  source_arn     = "arn:aws:events:${var.aws_region}:${var.aws_account_id}:rule/${var.project_id}-*"
}
