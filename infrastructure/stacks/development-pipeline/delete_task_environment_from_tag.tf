resource "aws_codebuild_webhook" "destroy_environment_from_tag_deployment_webhook" {
  count        = var.environment == "dev" ? 1 : 0
  project_name = aws_codebuild_project.di_destroy_environment_from_tag[0].name
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

resource "aws_codebuild_project" "di_destroy_environment_from_tag" {
  count          = var.environment == "dev" ? 1 : 0
  name           = "${var.project_id}-${var.environment}-destroy-task-environments-stage"
  description    = "Destroys task environment based on tag"
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
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "PROFILE"
      value = "task"
    }
    environment_variable {
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-destroy-task-environments-stage"
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID_LIVE_PARENT"
      value = var.aws_account_id_live_parent
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID_MGMT"
      value = var.aws_account_id_mgmt
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID_NONPROD"
      value = var.aws_account_id_nonprod
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID_PROD"
      value = var.aws_account_id_prod
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID_IDENTITIES"
      value = var.aws_account_id_identities
    }
  }
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-destroy-task-environments-stage"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = "https://github.com/nhsd-exeter/dos-integration.git"
    buildspec       = data.template_file.delete_task_environment_from_tag_buildspec.rendered
  }

}
