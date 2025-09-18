resource "aws_cloudwatch_event_rule" "setup_dos_environment_rule" {
  name                = "${var.project_id}-${var.environment}-setup-dos-environment-rule"
  description         = "Trigger the setup of a DOS environment on a schedule"
  schedule_expression = "cron(0 1 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "setup_dos_environment_trigger" {
  rule     = aws_cloudwatch_event_rule.setup_dos_environment_rule.name
  arn      = aws_codebuild_project.setup_dos_environment.arn
  role_arn = data.aws_iam_role.pipeline_role.arn
}

resource "aws_codebuild_project" "setup_dos_environment" {
  name           = "${var.project_id}-${var.environment}-setup-dos-environment-stage"
  description    = "Setup the DoS RegressionDI Environment"
  build_timeout  = "60"
  queued_timeout = "30"
  service_role   = data.aws_iam_role.pipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }


  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "PROFILE"
      value = "dev"
    }
    environment_variable {
      name  = "ENVIRONMENT"
      value = "test"
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
      group_name  = "/aws/codebuild/${var.project_id}-${var.environment}-setup-dos-environment-stage"
      stream_name = ""
    }
  }

  source {
    type            = "GITHUB"
    git_clone_depth = 0
    location        = var.github_url
    buildspec       = "infrastructure/stacks/development-and-deployment-tools/buildspecs/setup-dos-environment-buildspec.yml"
  }
  vpc_config {
    security_group_ids = [
      aws_security_group.codebuild_sg.id,
    ]
    subnets = [
      data.aws_subnet.vpc_subnet_one.id,
      data.aws_subnet.vpc_subnet_two.id,
      data.aws_subnet.vpc_subnet_three.id
    ]
    vpc_id = data.aws_vpc.texas_mgmt_vpc.id
  }
}
