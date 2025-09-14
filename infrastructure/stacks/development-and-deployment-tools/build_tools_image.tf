resource "aws_codebuild_webhook" "build_image_webhook" {
  for_each     = local.independent_build_images
  project_name = "${var.project_id}-${var.environment}-build-${each.key}-stage"
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED"
    }
    filter {
      type    = "FILE_PATH"
      pattern = local.independent_build_images[each.key].filematch
    }
  }
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_UPDATED"
    }
    filter {
      type    = "FILE_PATH"
      pattern = local.independent_build_images[each.key].filematch
    }
  }
  depends_on = [aws_codebuild_project.build_image]
}

resource "aws_codebuild_project" "build_image" {
  for_each       = local.independent_build_images
  name           = "${var.project_id}-${var.environment}-build-${each.key}-stage"
  description    = "Builds ${each.key} x86 development docker container image"
  build_timeout  = "10"
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
      name  = "ENVIRONMENT"
      value = "dev"
    }
    environment_variable {
      name  = "BUILD_TARGET"
      value = "${each.key}-build"
    }
    environment_variable {
      name  = "BUILD_ITEM_NAME"
      value = each.key
    }
    environment_variable {
      name  = "CB_PROJECT_NAME"
      value = "${var.project_id}-${var.environment}-build-${each.key}-stage"
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-build-${each.key}-image-stage"
      stream_name = ""
    }
  }
  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/buildspecs/build-tools-image-buildspec.yml"
  }
}
