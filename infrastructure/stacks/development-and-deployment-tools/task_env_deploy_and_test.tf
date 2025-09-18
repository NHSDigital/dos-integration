resource "aws_codebuild_webhook" "task_env_deploy_and_test_webhook" {
  project_name = aws_codebuild_project.task_env_deploy_and_test.name
  build_type   = "BUILD_BATCH"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/task/DS-[0-9]*"
    }
  }
  depends_on = [aws_codebuild_project.task_env_deploy_and_test]
}


resource "aws_codebuild_project" "task_env_deploy_and_test" {
  name           = "${var.project_id}-${var.environment}-task-env-deploy-and-test"
  description    = "Builds, deploys and tests task environment, triggered by a push to a task branch"
  build_timeout  = "90"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  build_batch_config {
    service_role    = data.aws_iam_role.pipeline_role.arn
    timeout_in_mins = 60
    restrictions {
      compute_types_allowed  = []
      maximum_builds_allowed = 100
    }
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-task-env-deploy-and-test"
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-task-env-deploy-and-test"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/batch-buildspecs/task-env-deploy-and-test-buildspec.yml"
  }
}
