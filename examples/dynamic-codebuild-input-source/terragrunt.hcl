include {
    path = find_in_parent_folders()
}

locals {
    aws_vars = read_terragrunt_config(find_in_parent_folders("aws.hcl"))
    account_id = local.aws_vars.locals.account_id
}

terraform {
    source = "../../modules//dynamic-codebuild-input-source"
}

inputs = {
    cmk_trusted_admin_arns = ["arn:aws:iam::${local.account_id}:role/cross-account-admin-access"]
    cmk_trusted_usage_arns = ["arn:aws:iam::${local.account_id}:role/cross-account-admin-access"]
    pipeline_name = "foo-pipeline"
    account_id = local.account_id
    source_repos = [
        {
            id = "https://github.com/marshall7m/terraform-aws-codebuild.git"
            webhook_filters = [
                {
                    json_path = "$.ref"
                    match_equals = "refs/heads/master"
                },
                {
                    json_path = "$.commits"
                    match_equals = "?(@.added =~ /.*.tf|.*.hcl/i)"
                }
            ]
        }
    ]
    test_stage_build = {
        name = "static-checks"
    }
    create_github_ssm_param = true
    ssm_github_secret_key = "test"
    ssm_github_secret_value = "quiz"
}