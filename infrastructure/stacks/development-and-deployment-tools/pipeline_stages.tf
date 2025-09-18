resource "aws_codebuild_project" "unit_tests_stage" {
  name           = "${var.project_id}-${var.environment}-unit-test-stage"
  description    = "Runs the unit tests for the DI Project"
  build_timeout  = "5"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    dynamic "environment_variable" {
      for_each = local.default_environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }

    environment_variable {
      name  = "TESTER_BUILD_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-build-tester-stage"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-unit-test-stage"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/unit-tests-buildspec.yml"
  }
}

resource "aws_codebuild_project" "build_image_stage" {
  name           = "${var.project_id}-${var.environment}-build-image-stage"
  description    = "Builds docker container image"
  build_timeout  = "15"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-build-stage"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/build-arm-image-in-pipeline-buildspec.yml"
  }
}

resource "aws_codebuild_project" "full_deploy_stage" {
  name           = "${var.project_id}-${var.environment}-deploy-stage"
  description    = "Deploy a full DI environment"
  build_timeout  = "30"
  queued_timeout = "60"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    # Requires - PROFILE, ENVIRONMENT and AWS_ACCOUNT to be set
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-deploy-stage"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/deploy-full-environment-buildspec.yml"
  }
}

resource "aws_codebuild_project" "deploy_blue_green_environment_stage" {
  name           = "${var.project_id}-${var.environment}-deploy-blue-green-environment-stage"
  description    = "Deploy a blue/green environment"
  build_timeout  = "30"
  queued_timeout = "10"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    # Requires - PROFILE, ENVIRONMENT and AWS_ACCOUNT to be set
    environment_variable {
      name  = "GIT_REPO_URL"
      value = var.github_url
    }

    environment_variable {
      name  = "DELETE_BLUE_GREEN_ENVIRONMENT_CODEBUILD_NAME"
      value = aws_codebuild_project.delete_blue_green_environment.name
    }

    environment_variable {
      name  = "NEW_VERSION_PARAMETER_NAME"
      value = var.blue_green_deployment_new_version_parameter_name
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-deploy-stage"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/deploy-blue-green-environment-buildspec.yml"
  }
  depends_on = [
    aws_codebuild_project.delete_blue_green_environment
  ]
}

resource "aws_codebuild_project" "deploy_shared_resources_environment_stage" {
  name           = "${var.project_id}-${var.environment}-deploy-shared-resources-environment-stage"
  description    = "Deploy a shared resources environment"
  build_timeout  = "30"
  queued_timeout = "10"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    # Requires - PROFILE, ENVIRONMENT and AWS_ACCOUNT to be set
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-deploy-shared-resources-environment-stage"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/deploy-shared-resources-environment-buildspec.yml"
  }
}

resource "aws_codebuild_project" "integration_tests" {
  for_each       = local.integration_test_tags
  name           = "${var.project_id}-${var.environment}-integration-tests-${each.key}"
  description    = "Runs the integration tests for the DI Project"
  build_timeout  = "60"
  queued_timeout = "10"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "TAG"
      value = each.key
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-integration-test-stage"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/integration-tests-buildspec.yml"
  }
}


resource "aws_codebuild_project" "trigger_rollback" {
  name           = "${var.project_id}-${var.environment}-trigger-rollback"
  description    = "Trigger rollback"
  build_timeout  = "30"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    dynamic "environment_variable" {
      for_each = local.default_environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }

    environment_variable {
      name  = "GIT_REPO_URL"
      value = var.github_url
    }
    environment_variable {
      name  = "PROJECT_REPO"
      value = "${var.github_owner}/${var.github_repo}"
    }
    environment_variable {
      name  = "ROLLBACK_PROJECT_NAME"
      value = aws_codebuild_project.blue_green_rollback_stage.name
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-trigger-rollback"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/trigger-rollback-buildspec.yml"
  }
}

resource "aws_codebuild_project" "production_smoke_test" {
  name           = "${var.project_id}-${var.environment}-production-smoke-test"
  description    = "Production smoke test"
  build_timeout  = "30"
  queued_timeout = "5"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-production-smoke-test"
      stream_name = ""
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "infrastructure/stacks/development-and-deployment-tools/buildspecs/production-smoke-test-buildspec.yml"
  }
}
