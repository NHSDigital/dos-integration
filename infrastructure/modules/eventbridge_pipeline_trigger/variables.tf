variable "bucket_name" {
  description = "Name of the S3 bucket to monitor."
  type        = string
}

variable "pipeline_arn" {
  description = "ARN of the CodePipeline to trigger."
  type        = string
}

variable "pipeline_role_arn" {
  description = "Role ARN for EventBridge to trigger the pipeline."
  type        = string
}

variable "rule_name" {
  description = "Name of the EventBridge rule."
  type        = string
}

variable "description" {
  description = "Description of the EventBridge rule."
  type        = string
}

variable "object_key" {
  description = "S3 object key to filter on."
  type        = string
  default     = "repository.zip"
}
