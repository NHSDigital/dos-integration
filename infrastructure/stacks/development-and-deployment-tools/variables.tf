# ##############
# # PIPELINE VARIABLES
# ##############
variable "development_pipeline_branch_name" {
  type        = string
  description = "Branch name for the development pipeline to track"
}

variable "cicd_blue_green_deployment_pipeline_artefact_bucket" {
  type        = string
  description = "The name of the S3 bucket where the artefacts are stored for the blue-green deployment pipeline"
}

variable "cicd_shared_resoures_deployment_pipeline_artefact_bucket" {
  type        = string
  description = "The name of the S3 bucket where the artefacts are stored for the shared resources deployment pipeline"
}

variable "cicd_blue_green_deployment_pipeline_name" {
  type        = string
  description = "The name of the blue/green deployment pipeline"
}

variable "cicd_shared_resources_deployment_pipeline_name" {
  type        = string
  description = "The name of the shared resources deployment pipeline"
}

variable "pipeline_notification_name" {
  type        = string
  description = "Development pipeline notification name"
}

variable "cicd_blue_green_deployment_pipeline_nofitication_name" {
  type        = string
  description = "Blue-green deployment pipeline notification name"
}

variable "cicd_shared_resources_deployment_pipeline_nofitication_name" {
  type        = string
  description = "Shared resources deployment pipeline notification name"
}

variable "cicd_blue_green_deployment_pipeline_eventbridge_rule_name" {
  type        = string
  description = "Shared resources deployment pipeline notification name"
}

variable "cicd_shared_resources_deployment_pipeline_eventbridge_rule_name" {
  type        = string
  description = "Shared resources deployment pipeline notification name"
}


variable "pipeline_chatbot_channel" {
  type        = string
  description = ""
}

variable "pipeline_topic_name" {
  type        = string
  description = ""
}

variable "github_owner" {
  type        = string
  description = ""
}

variable "github_repo" {
  type        = string
  description = ""
}

variable "github_url" {
  type        = string
  description = "The URL of the DoS Integration GitHub repository"
}

variable "mgmt_vpc_name" {
  type        = string
  description = "Name of the management VPC"
}

# ##############
# # PARAMETER STORE
# ##############

variable "blue_green_deployment_new_version_parameter_name" {
  type        = string
  description = "The name of the parameter in the parameter store that stores the new version of the blue/green deployment"
}

# ##############
# # OTHER
# ##############

variable "developer_role" {
  type        = string
  description = "The name of the developer role"
}


variable "github_token" {
  type        = string
  description = "GitHub token for the CodeBuild projects"
}

# ##############
# # KMS
# ##############

variable "development_tools_encryption_key_alias" {
  type        = string
  description = "The alias of the KMS key used to encrypt the development tools"
}
