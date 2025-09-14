resource "aws_codebuild_webhook" "build_cicd_blue_green_artefact_webhook" {
  project_name = aws_codebuild_project.build_cicd_blue_green_artefact.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "^refs/tags/.*-blue-green-deployment"
    }
  }
  depends_on = [aws_codebuild_project.build_cicd_blue_green_artefact]
}

resource "aws_codebuild_project" "build_cicd_blue_green_artefact" {
  name           = "${var.project_id}-${var.environment}-build-cicd-blue-green-artefact"
  description    = "Builds artefacts based on tag for CI/CD Pipeline"
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
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-build-cicd-blue-green-artefact"
    }
    environment_variable {
      name  = "CICD_BLUE_GREEN_DEPLOYMENT_PIPELINE"
      value = var.cicd_blue_green_deployment_pipeline_name
    }
    environment_variable {
      name  = "CICD_ARTIFACT_BUCKET"
      value = var.cicd_blue_green_deployment_pipeline_artefact_bucket
    }
    dynamic "environment_variable" {
      for_each = local.default_environment_variables
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }

    environment_variable {
      name  = "NEW_VERSION_PARAMETER_NAME"
      value = var.blue_green_deployment_new_version_parameter_name
    }

  }
  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-build-cicd-blue-green-artefact-stage"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/buildspecs/build-cicd-blue-green-deployment-artefact-buildspec.yml"
  }
  depends_on = [module.cicd_blue_green_deployment_pipeline_artefact_bucket]
}
