locals {
  # Codepipeline action role ARNs
  action_role_arns = distinct(compact([for action in flatten(var.stages[*].actions) : try(action.role_arn, "")]))
  # action role arns from the calling account
  calling_account_action_role_arns = [for arn in local.action_role_arns : arn if split(":", arn)[4] == var.account_id]
  # Cross-account AWS account_ids
  trusted_cross_account_ids = distinct([for arn in local.action_role_arns : split(":", arn)[4] if split(":", arn)[4] != var.account_id])
  # Cross-account AWS role resources used for CodePipeline IAM permissions
  trusted_cross_account_roles = formatlist("arn:aws:iam::%s:role/*", local.trusted_cross_account_ids)
  # Distinct CodePipeline action providers used for CodePipeline IAM permissions
  action_providers = distinct(flatten(var.stages[*].actions[*].provider))
  bucket_name = coalesce(var.artifact_bucket_name, lower("${var.name}-${random_string.artifact_bucket[0].result}"))
}

resource "aws_codepipeline" "this" {
  count = var.enabled ? 1 : 0

  name     = var.name
  role_arn = var.role_arn != null ? var.role_arn : module.role[0].role_arn

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  
    encryption_key {
      id = coalesce(var.cmk_arn, data.aws_kms_key.s3.arn)
      type = "KMS"
    }
  }

  dynamic "stage" {
    for_each = { for stage in var.stages : stage.name => stage }
    content {
      name = stage.key

      dynamic "action" {
        for_each = { for action in stage.value.actions : action.name => action }
        content {
          name             = action.value.name
          category         = action.value.category
          owner            = action.value.owner
          provider         = action.value.provider
          version          = action.value.version
          input_artifacts  = action.value.input_artifacts
          output_artifacts = action.value.output_artifacts
          run_order        = action.value.run_order
          role_arn         = action.value.role_arn
          region           = action.value.region
          namespace        = action.value.namespace
          configuration    = action.value.configuration
        }
      }
    }
  }
  tags = merge(var.pipeline_tags, var.common_tags)
}

#### IAM ####

module "role" {
  count  = var.enabled && var.role_arn == null ? 1 : 0
  source = "github.com/marshall7m/terraform-aws-iam/modules//iam-role"

  role_name               = var.name
  trusted_services        = ["codepipeline.amazonaws.com"]
  custom_role_policy_arns = [aws_iam_policy.permissions[0].arn]

  role_tags = merge(
    var.role_tags,
    var.common_tags
  )
}

data "aws_iam_policy_document" "permissions" {
  count = var.role_arn == null ? 1 : 0

  statement {
    sid    = "S3ArtifactBucketAccess"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values = [
        "cloudformation.amazonaws.com",
        "elasticbeanstalk.amazonaws.com",
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com"
      ]
    }
  }

  dynamic "statement" {
    for_each = length(local.trusted_cross_account_roles) > 0 ? [1] : []
    content {
      sid       = "CrossAccountActionAccess"
      effect    = "Allow"
      actions   = ["sts:AssumeRole"]
      resources = local.trusted_cross_account_roles
    }
  }

  dynamic "statement" {
    for_each = length(local.calling_account_action_role_arns) > 0 ? [1] : []
    content {
      sid       = "PipelineAccountActionAccess"
      effect    = "Allow"
      actions   = ["sts:AssumeRole"]
      resources = local.calling_account_action_role_arns
    }
  }

  dynamic "statement" {
    for_each = contains(local.action_providers, "CodeStarSourceConnection") ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["codestar-connections:UseConnection"]
      resources = compact([for action in flatten(var.stages[*].actions) : try(action.configuration["ConnectionArn"], "")])
    }
  }

  dynamic "statement" {
    for_each = contains(local.action_providers, "CodeBuild") ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild",
        "codebuild:BatchGetBuildBatches",
        "codebuild:StartBuildBatch"
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = contains(local.action_providers, "Manual") ? [1] : []
    content {
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = contains(local.action_providers, "CodeDeploy") ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "codedeploy:CreateDeployment",
        "codedeploy:GetApplication",
        "codedeploy:GetApplicationRevision",
        "codedeploy:GetDeployment",
        "codedeploy:GetDeploymentConfig",
        "codedeploy:RegisterApplicationRevision"
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_policy" "permissions" {
  count       = var.enabled && var.role_arn == null ? 1 : 0
  name        = var.name
  description = "Allows CodePipeline to assume defined service roles within the pipeline's actions and trigger AWS services defined within the pipeline's actions"
  path        = var.role_path
  policy      = data.aws_iam_policy_document.permissions[0].json
}

resource "random_string" "artifact_bucket" {
  count       = var.enabled ? 1 : 0
  length      = 10
  min_numeric = 5
  special     = false
  lower       = true
  upper       = false
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = true
  versioning {
    enabled = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.cmk_arn != null ? var.cmk_arn : data.aws_kms_key.s3.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
  tags          = var.artifact_bucket_tags
  policy = data.aws_iam_policy_document.artifacts.json
}

resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  policy = data.aws_iam_policy_document.artifacts.json
}


data "aws_iam_policy_document" "artifacts" {
  statement {
    sid    = "DenyUnencryptedUploads"
    effect = "Deny"
    actions   = ["s3:PutObject"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["arn:aws:s3:::${local.bucket_name}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid    = "DenyInsecureConnections"
    effect = "Deny"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${local.bucket_name}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_kms_key" "s3" {
  key_id = "alias/aws/s3"
}