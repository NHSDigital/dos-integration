resource "aws_codebuild_webhook" "destroy_environment_from_tag_deployment_webhook" {
  project_name = aws_codebuild_project.destroy_environment_from_tag.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "^refs/tags/.*-destroy.*$"
    }
  }
}

resource "aws_codebuild_project" "destroy_environment_from_tag" {
  name           = "${var.project_id}-${var.environment}-destroy-nonprod-environments-stage"
  description    = "Destroys nonprod environment based on tag"
  build_timeout  = "30"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }


  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "PROFILE"
      value = "dev"
    }
    environment_variable {
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-destroy-nonprod-environments-stage"
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-destroy-nonprod-environments-stage"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/buildspecs/delete-nonprod-environment-from-tag-buildspec.yml"
  }

}
