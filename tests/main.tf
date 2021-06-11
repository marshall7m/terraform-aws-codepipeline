locals {
  mut_id = "mut-aws-codepipeline-${lower(random_id.default.id)}"
}

provider "random" {}

resource "random_id" "default" {
  byte_length = 8
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "test" {
  bucket = local.mut_id
  acl    = "private"
  versioning {
    enabled = true
  }
  force_destroy = true
}

resource "aws_s3_bucket_object" "test" {
  bucket = aws_s3_bucket.test.id
  key    = "test_src.zip"
  source = "test_src.zip"
}

module "codebuild" {
  source = "github.com/marshall7m/terraform-aws-codebuild"
  name   = "${local.mut_id}-cb"
  artifacts = {
    type = "CODEPIPELINE"
  }

  environment = {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:3.0"
    type         = "LINUX_CONTAINER"
    environment_variables = [
      {
        name  = "FOO"
        type  = "PLAINTEXT"
        value = "baz"
      }
    ]
  }

  build_source = {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
version: 0.2
phases:
  build:
    commands:
      - echo $FOO
  EOF
  }
}

module "mut_codepipeline" {
  source     = "..//"
  name       = local.mut_id
  account_id = data.aws_caller_identity.current.id
  stages = [
    {
      name = "1-src"
      actions = [
        {
          name             = "source"
          category         = "Source"
          owner            = "AWS"
          provider         = "S3"
          version          = 1
          output_artifacts = ["test"]
          configuration = {
            S3Bucket    = aws_s3_bucket.test.id
            S3ObjectKey = aws_s3_bucket_object.test.source
          }
        }
      ]
    },
    {
      name = "2-build"
      actions = [
        {
          name            = "build"
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          version         = "1"
          input_artifacts = ["test"]
          configuration = {
            ProjectName = module.codebuild.name
            EnvironmentVariables = jsonencode([
              {
                name  = "FOO"
                type  = "PLAINTEXT"
                value = "bar"
              }
            ])
          }
        }
      ]
    },
    {
      name = "2-approval"
      actions = [
        {
          name             = "approval"
          category         = "Approval"
          owner            = "AWS"
          provider         = "Manual"
          version          = "1"
          output_artifacts = []
        }
      ]
    }
  ]
}