resource "aws_codebuild_webhook" "build_deploy_test_release_webhook" {
  project_name = aws_codebuild_project.build_deploy_test_release.name
  build_type   = "BUILD_BATCH"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/release/*"
    }
  }
  depends_on = [aws_codebuild_project.build_deploy_test_release]
}

resource "aws_codebuild_project" "build_deploy_test_release" {
  name           = "${var.project_id}-${var.environment}-build-deploy-test-release-stage"
  description    = "Builds, Deploys and Tests the release branch"
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
    timeout_in_mins = 120
    restrictions {
      compute_types_allowed  = []
      maximum_builds_allowed = 100
    }
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-build-deploy-test-release-stage"
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-build-deploy-test-release-stage"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/batch-buildspecs/build-deploy-test-release-buildspec.yml"
  }

}
