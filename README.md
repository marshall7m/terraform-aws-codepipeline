<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.15.0 |
| aws | >= 3.22 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 3.22 |
| random | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| account\_id | AWS account id used to create pipeline | `string` | n/a | yes |
| artifact\_bucket\_force\_destroy | Determines if all bucket content will be deleted if the bucket is deleted (error-free bucket deletion) | `bool` | `false` | no |
| artifact\_bucket\_name | AWS S3 bucket name used for storing Codepipeline artifacts | `string` | `null` | no |
| artifact\_bucket\_tags | Tags for AWS S3 bucket used to store pipeline artifacts | `map(string)` | `{}` | no |
| cmk\_arn | AWS KMS CMK (Customer Master Key) ARN used to encrypt Codepipeline artifacts | `string` | `null` | no |
| common\_tags | Tags to add to all resources | `map(string)` | `{}` | no |
| enabled | Determines if module should create resources or destroy pre-existing resources managed by this module | `bool` | `true` | no |
| name | Pipeline name | `string` | n/a | yes |
| pipeline\_tags | Tags to attach to the CodePipeline | `map(string)` | `{}` | no |
| role\_arn | Pre-existing IAM role ARN to use for the CodePipeline | `string` | `null` | no |
| role\_description | n/a | `string` | `"Allows Amazon Codepipeline to call AWS services on your behalf"` | no |
| role\_force\_detach\_policies | Determines attached policies to the CodePipeline service roles should be forcefully detached if the role is destroyed | `bool` | `false` | no |
| role\_max\_session\_duration | Max session duration (seconds) the role can be assumed for | `number` | `3600` | no |
| role\_path | Path to create policy | `string` | `"/"` | no |
| role\_permissions\_boundary | Permission boundary policy ARN used for CodePipeline service role | `string` | `""` | no |
| role\_tags | Tags to add to CodePipeline role | `map(string)` | `{}` | no |
| stages | List of pipeline stages (see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline) | <pre>list(object({<br>    name = string<br>    actions = list(object({<br>      name             = string<br>      category         = string<br>      owner            = string<br>      provider         = string<br>      version          = string<br>      configuration    = optional(map(string))<br>      input_artifacts  = optional(list(string))<br>      output_artifacts = optional(list(string))<br>      role_arn         = optional(string)<br>      run_order        = optional(number)<br>      region           = optional(string)<br>      namespace        = optional(string)<br>    }))<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| arn | ARN of pipeline |
| artifact\_bucket\_arn | ARN of the S3 bucket that will store the pipeline artifacts |
| artifact\_bucket\_id | S3 bucket that will store the pipeline artifacts |
| name | Name of pipeline |
| role\_arn | ARN of the IAM role that the pipeline will assume |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->