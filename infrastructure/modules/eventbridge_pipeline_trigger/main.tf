resource "aws_cloudwatch_event_rule" "trigger_pipeline" {
  name          = var.rule_name
  description   = var.description
  event_pattern = <<EOF
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "resources": ["arn:aws:s3:::${var.bucket_name}"],
  "detail": {
    "object": {
      "key": ["${var.object_key}"]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "pipeline_target" {
  rule     = aws_cloudwatch_event_rule.trigger_pipeline.name
  arn      = var.pipeline_arn
  role_arn = var.pipeline_role_arn
}
