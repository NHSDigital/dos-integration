resource "aws_codebuild_webhook" "build_cicd_shared_resources_artefact_webhook" {
  project_name = aws_codebuild_project.build_cicd_shared_resources_artefact.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "^refs/tags/.*-shared-resources-deployment"
    }
  }
  depends_on = [aws_codebuild_project.build_cicd_shared_resources_artefact]
}

resource "aws_codebuild_project" "build_cicd_shared_resources_artefact" {
  name           = "${var.project_id}-${var.environment}-build-cicd-shared-resources-artefact"
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
      value = "${var.project_id}-${var.environment}-build-cicd-shared-resources-artefact"
    }
    environment_variable {
      name  = "CICD_SHARED_RESOURCES_DEPLOYMENT_PIPELINE"
      value = var.cicd_shared_resources_deployment_pipeline_name
    }
    environment_variable {
      name  = "CICD_ARTIFACT_BUCKET"
      value = var.cicd_shared_resoures_deployment_pipeline_artefact_bucket
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-build-cicd-shared-resources-artefact-stage"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/buildspecs/build-cicd-shared-resources-artefact-buildspec.yml"
  }
  depends_on = [
    module.cicd_shared_resoures_deployment_pipeline_artefact_bucket
  ]
}
