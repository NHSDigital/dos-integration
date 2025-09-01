resource "aws_codepipeline" "cicd_shared_resources_deployment_pipeline" {
  #checkov:skip=CKV_AWS_219
  name     = var.cicd_shared_resources_deployment_pipeline_name
  role_arn = data.aws_iam_role.pipeline_role.arn

  artifact_store {
    location = var.cicd_shared_resoures_deployment_pipeline_artefact_bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      category         = "Source"
      name             = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        S3Bucket             = var.cicd_shared_resoures_deployment_pipeline_artefact_bucket
        S3ObjectKey          = "repository.zip"
        DetectChanges        = "True"
      }
    }
  }
  stage {
    name = "Deploy_Test_Environment"
    dynamic "action" {
      for_each = local.cicd_nonprod_environments
      content {
        name            = "Deploy_${action.value["SHARED_ENVIRONMENT"]}"
        category        = "Build"
        owner           = "AWS"
        run_order       = 1
        provider        = "CodeBuild"
        input_artifacts = ["source_output"]
        version         = "1"
        configuration = {
          ProjectName = aws_codebuild_project.deploy_shared_resources_environment_stage.name
          EnvironmentVariables = jsonencode([
            {
              name  = "AWS_ACCOUNT"
              value = "${action.value["AWS_ACCOUNT"]}"
              type  = "PLAINTEXT"
            },
            {
              name  = "PROFILE"
              value = "${action.value["PROFILE"]}"
              type  = "PLAINTEXT"
            },
            {
              name  = "SHARED_ENVIRONMENT"
              value = "${action.value["SHARED_ENVIRONMENT"]}"
              type  = "PLAINTEXT"
            }
          ])
        }
      }
    }
    dynamic "action" {
      for_each = local.integration_test_tags
      content {
        name            = "Integration_Test_${action.key}"
        category        = "Build"
        owner           = "AWS"
        provider        = "CodeBuild"
        input_artifacts = ["source_output"]
        version         = "1"
        run_order       = 2
        configuration = {
          ProjectName = aws_codebuild_project.integration_tests[action.key].name
          EnvironmentVariables = jsonencode([
            {
              name  = "PROFILE"
              value = "dev"
              type  = "PLAINTEXT"
            },
            {
              name  = "SHARED_ENVIRONMENT"
              value = "cicd-test"
              type  = "PLAINTEXT"
            }
          ])
        }
      }
    }
  }
  stage {
    name = "Deploy_Cicd_Release_Environment"
    dynamic "action" {
      for_each = local.cicd_prod_environments
      content {
        name            = "Deploy_${action.value["SHARED_ENVIRONMENT"]}"
        category        = "Build"
        owner           = "AWS"
        run_order       = 1
        provider        = "CodeBuild"
        input_artifacts = ["source_output"]
        version         = "1"
        configuration = {
          ProjectName = aws_codebuild_project.deploy_shared_resources_environment_stage.name
          EnvironmentVariables = jsonencode([
            {
              name  = "AWS_ACCOUNT"
              value = "${action.value["AWS_ACCOUNT"]}"
              type  = "PLAINTEXT"
            },
            {
              name  = "PROFILE"
              value = "${action.value["PROFILE"]}"
              type  = "PLAINTEXT"
            },
            {
              name  = "SHARED_ENVIRONMENT"
              value = "${action.value["SHARED_ENVIRONMENT"]}"
              type  = "PLAINTEXT"
            }
          ])
        }
      }
    }
    action {
      name            = "Smoke_Test_New_Version"
      category        = "Build"
      owner           = "AWS"
      run_order       = 2
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.production_smoke_test.name
        EnvironmentVariables = jsonencode([
          {
            name  = "PROFILE"
            value = "demo"
            type  = "PLAINTEXT"
          },
          {
            name  = "ENVIRONMENT"
            value = "cicd-release"
            type  = "PLAINTEXT"
          },
          {
            name  = "AWS_ACCOUNT"
            value = "PROD"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
  stage {
    name = "Approve"

    action {
      name     = "Approve_Live_Deployment"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Approve the deployment to the live environment"
      }
    }
  }
  stage {
    name = "Deploy_Live_Environment"
    action {
      name            = "Deploy_Live"
      category        = "Build"
      owner           = "AWS"
      run_order       = 1
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.deploy_shared_resources_environment_stage.name
        EnvironmentVariables = jsonencode([
          {
            name  = "AWS_ACCOUNT"
            value = "PROD"
            type  = "PLAINTEXT"
          },
          {
            name  = "PROFILE"
            value = "live"
            type  = "PLAINTEXT"
          },
          {
            name  = "SHARED_ENVIRONMENT"
            value = "live"
            type  = "PLAINTEXT"
          }
        ])
      }
    }
  }
  depends_on = [
    module.cicd_blue_green_deployment_pipeline_artefact_bucket,
    aws_codebuild_project.unit_tests_stage,
    aws_codebuild_project.integration_tests,
    aws_codebuild_project.deploy_shared_resources_environment_stage,
  ]
}

module "cicd_shared_resoures_deployment_pipeline_artefact_bucket" {
  source             = "../../modules/s3"
  name               = var.cicd_shared_resoures_deployment_pipeline_artefact_bucket
  project_id         = var.project_id
  acl                = "private"
  versioning_enabled = "true"
  force_destroy      = "true"
}
