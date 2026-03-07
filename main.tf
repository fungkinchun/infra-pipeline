provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_caller_identity" "current" {}

locals {
  full_project_name = "${var.project_name}-infra"
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "codebuild.amazonaws.com",
        "codeartifact.amazonaws.com",
        "codepipeline.amazonaws.com",
        "codestar.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }
}
# Create S3 bucket for infra-pipeline Terraform state
resource "aws_s3_bucket" "pipeline_terraform_state" {
  bucket = "${local.full_project_name}-pipeline-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "pipeline_terraform_state_versioning" {
  bucket = aws_s3_bucket.pipeline_terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Create S3 bucket for infra Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${local.full_project_name}-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "pipeline_artifact" {
  bucket        = "${local.full_project_name}-pipeline-artifact"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "pipeline_artifact_versioning" {
  bucket = aws_s3_bucket.pipeline_artifact.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${local.full_project_name}-terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_secretsmanager_secret" "infra_credentials" {
  name                    = "${var.project_name}-infra"
  description             = "Credentials for ${var.project_name} infra"
  recovery_window_in_days = 0

  tags = {
    Project     = "${var.project_name}-infra"
    Terraform   = "true"
    Sensitivity = "high"
  }
}

resource "aws_secretsmanager_secret_version" "s3_credentials_version" {
  secret_id     = aws_secretsmanager_secret.infra_credentials.id
  secret_string = jsonencode(var.infra_credentials)
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${local.full_project_name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
}

resource "aws_iam_role_policy" "codebuild_policy" {
  role   = aws_iam_role.codebuild_role.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

resource "aws_codebuild_project" "codebuild_project_plan" {
  name         = "${local.full_project_name}-plan"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_VERSION"
      value = "1.14.6"
    }

    environment_variable {
      name  = "AWS_SECRET_NAME"
      value = aws_secretsmanager_secret.infra_credentials.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec_plan.yaml"
  }
}

resource "aws_codebuild_project" "codebuild_project_apply" {
  name         = "${local.full_project_name}-apply"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_VERSION"
      value = "1.14.6"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec_apply.yaml"
  }
}

resource "aws_codebuild_project" "codebuild_project_destroy" {
  name         = "${local.full_project_name}-destroy"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_VERSION"
      value = "1.14.6"
    }

    environment_variable {
      name  = "AWS_SECRET_NAME"
      value = aws_secretsmanager_secret.infra_credentials.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec_destroy.yaml"
  }
}

resource "aws_codebuild_project" "codebuild_project_helm_deploy" {
  name         = "${local.full_project_name}-helm-deploy"
  service_role = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = "${var.project_name}-${var.environment}-eks"
    }

    environment_variable {
      name  = "PROJECT_NAME"
      value = var.project_name
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec_helm.yaml"
  }
}

resource "aws_codepipeline" "terraform_pipeline" {
  name     = "${local.full_project_name}-pipeline"
  role_arn = aws_iam_role.codebuild_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_username}/${local.full_project_name}"
        BranchName       = "main"
      }
    }

    action {
      name             = "Helm_Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["helm_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_username}/${var.project_name}-helm"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "TF_Plan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["tf_plan_output"]
      version          = "1"

      configuration = {
        ProjectName = "${local.full_project_name}-plan"
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "Manual_Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "Apply"

    action {
      name             = "TF_Apply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output", "tf_plan_output"]
      output_artifacts = ["tf_apply_output"]
      version          = "1"

      configuration = {
        ProjectName   = "${local.full_project_name}-apply"
        PrimarySource = "source_output"
      }
    }
  }



  stage {
    name = "Helm_Deploy"

    action {
      name            = "Helm_Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["tf_apply_output", "helm_output"]
      version         = "1"

      configuration = {
        ProjectName   = "${local.full_project_name}-helm-deploy"
        PrimarySource = "helm_output"
      }
    }
  }
}

resource "aws_codepipeline" "destroy_pipeline" {
  name     = "${local.full_project_name}-destroy-pipeline"
  role_arn = aws_iam_role.codebuild_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_username}/${local.full_project_name}"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "Manual_Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
    }
  }

  stage {
    name = "Destroy"

    action {
      name            = "TF_Destroy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = "${local.full_project_name}-destroy"
      }
    }
  }
}
