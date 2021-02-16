include {
    path = find_in_parent_folders("aws.hcl")
}

locals {
    aws_vars = read_terragrunt_config(find_in_parent_folders("aws.hcl"))
    account_id = local.aws_vars.locals.account_id
}

terraform {
    source = "../../modules//dynamic-codebuild-input-source"
}

dependency "github_repos" {
    config_path = "${get_terragrunt_dir()}/github_repos"
}

inputs = {
    cmk_trusted_admin_arns = ["d"]
    pipeline_name = "foo-pipeline"
    account_id = local.account_id
    source_repos = [
        {
            id = dependency.github_repos.outputs.repo_clone_urls["foo"]
        }
    ]
    test_stage_build = {
        name = "static-checks"
        environment = {}
        source = {}
    }
}