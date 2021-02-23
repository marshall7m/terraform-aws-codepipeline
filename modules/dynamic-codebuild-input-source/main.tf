locals {
  source_repos = [for repo in var.source_repos : merge(
    {
      name = trimsuffix(element(split("/", repo.id), length(split("/", repo.id))-1), ".git")
    },
    defaults(repo, {
      branch            = "master"
      global_buildspec  = false
      codestar_conn_arn = module.codestar[0].arn[var.codestar_conn.name]
      webhook_filters = {
        json_path = null
        match_equals = null
      }
    })
  )]
  source_stage = {
    name = var.source_stage_name
    actions = concat([for repo in local.source_repos : {
      name             = repo.name
      category         = "Source"
      owner            = "AWS"
      version          = 1
      provider         = "CodeStarSourceConnection"
      output_artifacts = [repo.name]
      configuration = {
        ConnectionArn    = repo.codestar_conn_arn
        FullRepositoryId = repo.id
        BranchName       = repo.branch
        DetectChanges = false
      }
    }], length(var.primary_buildspecs) > 0 ? [{
      name             = "s3-buildspecs"
      category         = "Source"
      owner            = "AWS"
      version          = 1
      provider         = "S3"
      output_artifacts = ["s3-buildspecs"]
      configuration = {
        S3Bucket = module.s3[0].id
        S3ObjectKey = var.primary_buildspecs_key
        PollForSourceChanges = false
      }
    }] : [])
  }

  invoke_stage = {
    name = var.invoke_stage_name
    actions = [
      {
        name             = var.invoke_stage_name
        category         = "Invoke"
        owner            = "AWS"
        provider         = "Lambda"
        version          = 1
        input_artifacts  = []
        output_artifacts = ["invoke-output"]
        namespace = "TriggeredSource"
        configuration = {
          FunctionName = "update_test_source.zip"
          UserParameters = "{'pipeline_name': '${var.pipeline_name}'}"
        }
      }
    ]
  }
  test_stage = {
    name = var.test_stage_name
    actions = [
      {
        name             = var.test_stage_build.name
        category         = "Test"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = 1
        input_artifacts  = length(var.primary_buildspecs) > 1 ? ["s3-buildspecs", "#{TriggeredSource.RepoName}"] : ["#{TriggeredSource.RepoName}"]
        output_artifacts = ["${var.test_stage_build.name}-output"]
        configuration = {
          ProjectName          = var.test_stage_build.name
          EnvironmentVariables = try(var.test_stage_build.environment.environment_variables, null)
          BatchEnabled         = var.test_stage_build.batch_enabled
          CombineArtifacts     = var.test_stage_build.combine_artifacts
        }
      }
    ]
  }
  stages = [local.source_stage, local.invoke_stage, local.test_stage]
}

resource "random_integer" "artifact_bucket" {
  count = var.enabled ? 1 : 0
  min   = 10000000
  max   = 99999999
  seed  = 1
}

module "s3" {
  count  = var.enabled ? 1 : 0
  source = "github.com/marshall7m/terraform-aws-s3/modules//bucket"
  name   = coalesce(var.artifact_bucket_name, "${var.pipeline_name}-${random_integer.artifact_bucket[0].result}")
}

resource "aws_s3_bucket_object" "buildspecs" {
  count = length(var.primary_buildspecs)
  bucket = module.s3[0].id
  key    = "${var.primary_buildspecs_key}/${var.primary_buildspecs[count.index]}"
  source = var.primary_buildspecs[count.index]
}

module "lambda" {
    count = var.enabled ? 1 : 0
    source = "github.com/marshall7m/terraform-aws-lambda/modules//function"
    filename = "update_test_source.zip"
    function_name = "update_test_source"
    handler = "lambda_handler"
    runtime = "python3.8"
    allowed_to_invoke_arns = [module.codepipeline[0].arn]
}

module "codestar" {
  count       = var.enabled ? 1 : 0
  source      = "github.com/marshall7m/terraform-modules/terraform-aws-codestar-conn"
  connections = [var.codestar_conn]
}

module "codebuild" {
  count                             = var.enabled ? 1 : 0
  source                            = "github.com/marshall7m/terraform-aws-codebuild/modules//main"
  name                              = var.test_stage_build.name
  assumable_role_arns               = coalesce(var.test_stage_build.assumable_role_arns, [])
  environment                       = merge({
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    compute_type = "BUILD_GENERAL1_MEDIUM"
    type         = "LINUX_CONTAINER"
  }, var.test_stage_build.environment)
  codepipeline_artifact_bucket_name = module.s3[0].arn
  artifacts = {
    type = "CODEPIPELINE"
  }
  cache        = var.test_stage_build.cache
  build_source = merge(var.test_stage_build.source, {
    type                = "CODEPIPELINE"
    report_build_status = true
  })
  build_tags   = var.test_stage_build.tags
}

module "cmk" {
  count              = var.enabled && var.cmk_arn == null ? 1 : 0
  source             = "github.com/marshall7m/terraform-aws-kms/modules/cmk"
  account_id         = var.account_id
  trusted_admin_arns = var.cmk_trusted_admin_arns
  trusted_usage_arns = concat(var.cmk_trusted_usage_arns, [module.codebuild[0].role_arn])
  alias              = var.pipeline_name
  tags               = var.cmk_tags
}

module "codepipeline" {
  count                = var.enabled ? 1 : 0
  source               = "../main"
  account_id           = var.account_id
  name                 = var.pipeline_name
  cmk_arn              = module.cmk[0].arn
  artifact_bucket_name = coalesce(var.artifact_bucket_name, "${var.pipeline_name}-${random_integer.artifact_bucket[0].result}")
  stages               = local.stages
}

resource "aws_codepipeline_webhook" "this" {
  for_each        = { for repo in local.source_repos : repo.name => repo }
  name            = each.value.name
  authentication  = "GITHUB_HMAC"
  target_action   = each.value.name
  target_pipeline = module.codepipeline[0].name

  authentication_configuration {
    secret_token = var.create_github_ssm_param ? aws_ssm_parameter.github_secret[0].value : data.aws_ssm_parameter.github_secret[0]
  }

  dynamic "filter" {
    for_each = toset(each.value.webhook_filters)
    content {
      json_path    = filter.value.json_path
      match_equals = filter.value.match_equals
    }
  }
}

resource "aws_ssm_parameter" "github_secret" {
  count       = var.create_github_ssm_param ? 1 : 0
  name        = var.ssm_github_secret_key
  description = "Github webhook secret for source repos used for AWS CodePipeline: ${module.codepipeline[0].name}"
  type        = "SecureString"
  value       = var.ssm_github_secret_value
  tags = var.ssm_github_tags
}

data "aws_ssm_parameter" "github_secret" {
  count = var.create_github_ssm_param == false ? 1 : 0
  name  = var.ssm_github_secret_key
}

resource "github_repository_webhook" "this" {
  for_each   = var.enabled ? { for repo in local.source_repos : repo.name => repo } : {}
  repository = each.value.name

  configuration {
    url          = aws_codepipeline_webhook.this[each.value.name].url
    content_type = "json"
    insecure_ssl = false
    secret       = var.create_github_ssm_param ? aws_ssm_parameter.github_secret[0].value : data.aws_ssm_parameter.github_secret[0].value
  }

  events = ["push", "pull_request"]
}