locals {
  mut = basename(path.cwd)
}

provider "random" {}

resource "random_id" "default" {
  byte_length = 8
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "test" {
  bucket = "mut-codepipeline-${random_id.default.id}"
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

module "mut_codepipeline" {
  source     = "..//"
  name       = "${local.mut}-${random_id.default.id}"
  account_id = data.aws_caller_identity.current.id
  stages = [
    {
      name = "test-s3"
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