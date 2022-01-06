resource "aws_api_gateway_rest_api" "di_endpoint" {
  name        = var.di_endpoint_api_gateway_name
  description = "DI Change Event Endpoint: ${var.di_endpoint_api_gateway_stage}"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "di_endpoint_version_path" {
  parent_id   = aws_api_gateway_rest_api.di_endpoint.root_resource_id
  path_part   = "v1"
  rest_api_id = aws_api_gateway_rest_api.di_endpoint.id
}

resource "aws_api_gateway_resource" "di_endpoint_change_event_path" {
  parent_id   = aws_api_gateway_resource.di_endpoint_version_path.id
  path_part   = "change-event"
  rest_api_id = aws_api_gateway_rest_api.di_endpoint.id
}

resource "aws_api_gateway_method" "di_endpoint_method" {
  http_method      = "POST"
  resource_id      = aws_api_gateway_resource.di_endpoint_change_event_path.id
  rest_api_id      = aws_api_gateway_rest_api.di_endpoint.id
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method_settings" "di_endpoint_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.di_endpoint.id
  stage_name  = aws_api_gateway_stage.di_endpoint_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_integration" "di_endpoint_integration" {
  http_method             = aws_api_gateway_method.di_endpoint_method.http_method
  resource_id             = aws_api_gateway_resource.di_endpoint_change_event_path.id
  rest_api_id             = aws_api_gateway_rest_api.di_endpoint.id
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${var.aws_account_id}/${var.fifo_queue_name}"
  credentials             = aws_iam_role.di_endpoint_role.arn
  passthrough_behavior    = "NEVER"
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  request_templates = {
    "application/json" = <<EOF
#if( $input.params().header.get('correlation-id').toString() != "" )
#set($correlation_id = $util.escapeJavaScript($input.params("correlation-id")))
#else
#set($correlation_id = $context.requestId)
#end
Action=SendMessage&MessageGroupId=$input.json("ODSCode")&MessageBody=$input.body&MessageAttribute.1.Name=correlation-id&MessageAttribute.1.Value.DataType=String&MessageAttribute.1.Value.StringValue=$correlation_id&MessageAttribute.2.Name=sequence-number&MessageAttribute.2.Value.DataType=Number&MessageAttribute.2.Value.StringValue=$util.escapeJavaScript($input.params("sequence-number"))
EOF
  }
}

resource "aws_api_gateway_deployment" "di_endpoint_deployment" {
  rest_api_id = aws_api_gateway_rest_api.di_endpoint.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.di_endpoint_change_event_path,
      aws_api_gateway_method.di_endpoint_method,
      aws_api_gateway_integration.di_endpoint_integration,
      aws_api_gateway_integration.di_endpoint_integration.request_templates,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "di_endpoint_stage" {
  deployment_id        = aws_api_gateway_deployment.di_endpoint_deployment.id
  rest_api_id          = aws_api_gateway_rest_api.di_endpoint.id
  stage_name           = var.di_endpoint_api_gateway_stage
  xray_tracing_enabled = true
}

resource "aws_api_gateway_usage_plan" "di_endpoint_usage_plan" {
  name = "${var.di_endpoint_api_gateway_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.di_endpoint.id
    stage  = aws_api_gateway_stage.di_endpoint_stage.stage_name
  }
}

resource "aws_api_gateway_api_key" "di_endpoint_api_key" {
  name  = var.api_gateway_api_key_name
  value = jsondecode(data.aws_secretsmanager_secret_version.api_key.secret_string)[var.nhs_uk_api_key_key]
}

resource "aws_api_gateway_usage_plan_key" "di_endpoint_api_key_on_usage_plan" {
  key_id        = aws_api_gateway_api_key.di_endpoint_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.di_endpoint_usage_plan.id
}
