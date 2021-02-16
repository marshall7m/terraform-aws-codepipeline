include {
    path = find_in_parent_folders("github.hcl")
}

terraform {
    source = "github.com/marshall7m/terraform-github-repo/modules//repos-files"
}

inputs = {
    repos = [
        {
            name = "foo"
            files = [
                {
                    branch = "master"
                    file = "main.tf"
                    content = "foo"
                    commit_message = "test terraform module"
                    overwrite_on_create = true
                }
            ]
        },
        {
            name = "bar"
            files = [
                {
                    branch = "master"
                    file = "main.tf"
                    content = "bar"
                    commit_message = "test terraform module"
                    overwrite_on_create = true
                }
            ]
        }
    ]
}