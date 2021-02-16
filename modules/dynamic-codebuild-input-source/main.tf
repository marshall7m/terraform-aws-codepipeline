locals {
    source_repos = [for repo in var.source_repos: defaults(repo, {
        branch = "master"
        global_buildspec = false
        codestar_conn_arn = module.codestar[0].arn[var.codestar_conn.name]
    })]
    source_stage = {
        name = var.source_stage_name
        actions = [for repo in local.source_repos: {
            name = split("/", repo.id)[1]
            category = "Source"
            owner = "AWS"
            version = 1
            provider = "CodeStarSourceConnection"
            output_artifacts = [repo.branch]
            configuration = {
                ConnectionArn = repo.codestar_conn_arn
                FullRepositoryId = repo.id
                BranchName = repo.branch
            }
        }]
    }
    test_stage_build = defaults(var.test_stage_build, {
        environment = {
            image = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
            compute_type = "BUILD_GENERAL1_MEDIUM"
            type = "LINUX_CONTAINER"
        }
        source = {
            buildspec = "buildspec.yaml"
            report_build_status = true
        }
    })
    test_stage = {
        name = var.test_stage_name
        actions = [
            {
                name = local.test_stage_build.name
                category = "Test"
                owner = "AWS"
                provider = "CodeBuild"
                version = 1
                input_artifacts = [for repo in local.source_repos: repo.branch if repo.global_buildspec]
                output_artifacts = ["${local.test_stage_build.name}-output"]
                configuration = {
                    ProjectName = local.test_stage_build.name
                    EnvironmentVariables = local.test_stage_build.environment.environment_variables
                    BatchEnabled = local.test_stage_build.batch_enabled
                    CombineArtifacts = local.test_stage_build.combine_artifacts
                }
            }
        ]
    }
    # stages = concat(local.source_stage, local.test_stage)
}

output "src" {
    value = local.source_stage
}

output "test" {
    value = local.test_stage
}

resource "random_integer" "artifact_bucket" {
  count = var.enabled ? 1 : 0
  min = 10000000
  max = 99999999
  seed = 1
}

module "s3" {
    count = var.enabled ? 1 : 0
    source = "github.com/marshall7m/terraform-aws-s3/modules//bucket"
    name = coalesce(var.artifact_bucket_name, "${var.pipeline_name}-${random_integer.artifact_bucket[0].result}")
}

# module "lambda" {
#     count = var.enabled ? 1 : 0
#     source = "github.com/marshall7m/terraform-modules/terraform-aws-s3"
#     name = var.pipeline_name
# }

module "codestar" {
    count = var.enabled ? 1 : 0
    source = "github.com/marshall7m/terraform-modules/terraform-aws-codestar-conn"
    connections = [var.codestar_conn]
}

module "codebuild" {
    count = var.enabled ? 1 : 0
    source = "github.com/marshall7m/terraform-modules/terraform-aws-codebuild"
    name = local.test_stage_build.name
    assumable_role_arns = local.test_stage_build.assumable_role_arns
    environment = local.test_stage_build.environment
    codepipeline_artifact_bucket_name = module.s3[0].arn
    artifacts = {
        type = "CODEPIPELINE"
    }
    cache = local.test_stage_build.cache
    build_source = {
        type = "CODEPIPELINE"
        buildspec = local.test_stage_build.source.buildspec
    }
    build_tags = local.test_stage_build.tags
}

# module "cmk" {
#     count = var.enabled && var.cmk_arn == null ? 1 : 0
#     source = "github.com/marshall7m/terraform-modules/terraform-aws-cmk"
#     account_id = var.account_id
#     trusted_admin_arns = var.cmk_trusted_admin_arns
#     trusted_usage_arns = concat(var.cmk_trusted_usage_arns, [module.codebuild[0].role_arn])
#     alias = var.cmk_alias
#     tags = var.cmk_tags
# }

# module "codepipeline" {
#     count = var.enabled ? 1 : 0
#     source = "../main"
#     account_id = var.account_id
#     name = var.pipeline_name
#     cmk_arn = module.cmk[0].arn
#     artifact_bucket_name = coalesce(var.artifact_bucket_name, "${var.pipeline_name}-${random_integer.artifact_bucket[0].result}")
#     stages = local.stages
# }
