# resource "aws_cloudwatch_event_rule" "delete_ecr_images_rule" {
#   count               = var.environment == "dev" ? 1 : 0
#   name                = "${var.project_id}-${var.environment}-delete-ecr-images-rule"
#   description         = "Delete ECR images on the first of every month"
#   schedule_expression = "cron(0 0 1 * ? *)"
# }

# resource "aws_cloudwatch_event_target" "delete_ecr_images_trigger" {
#   count    = var.environment == "dev" ? 1 : 0
#   rule     = aws_cloudwatch_event_rule.delete_ecr_images_rule[0].name
#   arn      = aws_codebuild_project.di_delete_ecr_images[0].arn
#   role_arn = data.aws_iam_role.pipeline_role.arn
# }

resource "aws_codebuild_project" "di_delete_ecr_images" {
  count          = var.environment == "dev" ? 1 : 0
  name           = "${var.project_id}-${var.environment}-delete-ecr-images-stage"
  description    = "Deletes ECR images"
  build_timeout  = "30"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }


  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "PROFILE"
      value = "dev"
    }
    environment_variable {
      name  = "ENVIRONMENT"
      value = "dev"
    }
    environment_variable {
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-delete-ecr-images-stage"
    }
    dynamic "environment_variable" {
      for_each = local.default_environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }

  }
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-delete-ecr-images"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = file("buildspecs/delete-ecr-images-buildspec.yml")
  }
}
