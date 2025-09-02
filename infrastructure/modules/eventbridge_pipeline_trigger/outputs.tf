output "eventbridge_rule_id" {
  description = "The EventBridge rule Name we just created."
  value       = aws_cloudwatch_event_rule.trigger_pipeline.id
}

output "eventbridge_rule_arn" {
  description = "The EventBridge rule ARN we just created."
  value       = aws_cloudwatch_event_rule.trigger_pipeline.arn
}
