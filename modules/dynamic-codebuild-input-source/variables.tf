variable "enabled" {
  description = "Determines if module should create resources or destroy pre-existing resources managed by this module"
  type        = bool
  default     = true
}

variable "account_id" {
  description = "AWS account id"
  type        = number
}

variable "common_tags" {
  description = "Tags to add to all resources"
  type        = map(string)
  default     = {}
}

#### CODEPIPELINE ####

variable "role_arn" {
  description = "Pre-existing IAM role ARN to use for the CodePipeline"
  type        = string
  default     = null
}

variable "pipeline_name" {
  description = "Pipeline name"
  type        = string
  default     = "infrastructure-modules-ci"
}

variable "create_artifact_bucket" {
  description = "Determines if a S3 bucket should be created for storing the pipeline's artifacts"
  type        = bool
  default     = true
}

variable "artifact_bucket_name" {
  description = "Name of the artifact S3 bucket to be created or the name of a pre-existing bucket name to be used for storing the pipeline's artifacts"
  default     = null
}

variable "artifact_bucket_force_destroy" {
  description = "Determines if all bucket content will be deleted if the bucket is deleted (error-free bucket deletion)"
  type        = bool
  default     = false
}

variable "arifact_bucket_tags" {
  description = "Tags to attach to provisioned S3 bucket"
  type        = map(string)
  default     = {}
}

variable "source_stage_name" {
  description = "Name for CodePipeline source stage"
  type        = string
  default     = "github-source"
}

variable "source_repos" {
  # TODO: Allow for optional webhook_filters when issue is fixed: https://github.com/hashicorp/terraform/issues/27385
  description = "Third-party source stage configurations. Each action represent one source"
  type = list(object({
    id                = string
    codestar_conn_arn = optional(string)
    branch            = optional(string)
    global_buildspec  = optional(bool)
    webhook_filters   = list(object({
      json_path = string
      match_equals = string
    }))
  }))
}

variable "create_github_ssm_param" {
  description = "Determines if module should create (true) or load (false) the SSM parameter for Github webhook secret"
  type        = bool
  default     = false
}
variable "ssm_github_secret_key" {
  description = "Key for github secret within AWS SSM Parameter Store"
  type        = string
  default     = ""
}

variable "ssm_github_secret_value" {
  description = "Sensitive value for github secret within AWS SSM Parameter Store"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssm_github_tags" {
  description = "Tags for Github webhook secret SSM parameter"
  type        = map(string)
  default     = {}
}

variable "invoke_stage_name" {
  description = "Name for CodePipeline invoke stage"
  type = string
  default = "invoke"
}

variable "test_stage_name" {
  description = "Name for CodePipeline test stage"
  type        = string
  default     = "tests"
}

variable "primary_buildspecs" {
  description = <<EOF
Relative file path(s) to the global Codebuild buildspec files. 
If not defined here, individual buildspec can be defined in each source_repos.source.buildspec attribute
EOF
  type = list
  default = []
}

variable "primary_buildspecs_key" {
  description = "S3 key for the primary buildspec files"
  type = string
  default = "codebuild-buildspecs"
}

variable "test_stage_build" {
  type = object({
    name                = string
    assumable_role_arns = optional(list(string))
    cache = optional(object({
      type     = optional(string)
      location = optional(string)
      modes    = optional(list(string))
    }))
    environment = optional(object({
      compute_type                = optional(string)
      image                       = optional(string)
      type                        = optional(string)
      image_pull_credentials_type = optional(string)
      environment_variables = optional(list(object({
        name  = optional(string)
        value = optional(string)
        type  = optional(string)
      })))
      privileged_mode = optional(bool)
      certificate     = optional(string)
      registry_credential = optional(object({
        credential          = optional(string)
        credential_provider = optional(string)
      }))
    }))
    source = optional(object({
      git_clone_depth = optional(string)
      git_submodules_config = optional(object({
        fetch_submodules = optional(bool)
      }))
      insecure_ssl        = optional(bool)
      report_build_status = optional(bool)
    }))
    batch_enabled     = optional(bool)
    combine_artifacts = optional(bool)
    tags              = optional(map(string))
  })
}

variable "pipeline_tags" {
  description = "Tags to attach to the pipeline"
  type        = map(string)
  default     = {}
}

variable "role_path" {
  description = "Path to create policy"
  default     = "/"
}

variable "role_max_session_duration" {
  description = "Max session duration (seconds) the role can be assumed for"
  default     = 3600
  type        = number
}

variable "role_description" {
  default = "Allows Amazon Codepipeline to call AWS services on your behalf"
}

variable "role_force_detach_policies" {
  description = "Determines attached policies to the CodePipeline service roles should be forcefully detached if the role is destroyed"
  type        = bool
  default     = false
}

variable "role_permissions_boundary" {
  description = "Permission boundary policy ARN used for CodePipeline service role"
  type        = string
  default     = ""
}

variable "role_tags" {
  description = "Tags to add to CodePipeline service role"
  type        = map(string)
  default     = {}
}

#### KMS-CMK ####

variable "encrypt_artifacts" {
  description = "Determines if the Pipeline's artifacts will be encrypted via CMK"
  type        = bool
  default     = true
}

variable "cmk_trusted_admin_arns" {
  description = "AWS ARNs of trusted entities that can perform administrative actions on the CMK"
  type        = list(string)
}

variable "cmk_trusted_usage_arns" {
  description = "AWS ARNs of trusted entities that can use the CMK"
  type        = list(string)
}

variable "cmk_arn" {
  description = "ARN of a pre-existing CMK to use for encrypting CodePipeline artifacts at rest"
  type        = string
  default     = null
}

variable "cmk_tags" {
  description = "Tags to attach to the CMK"
  type        = map(string)
  default     = {}
}

variable "cmk_alias" {
  description = "Alias for CMK"
  type        = string
  default     = null
}

#### CODESTAR ####
variable "codestar_conn" {
  description = "AWS CodeStar connection configuration used to define the source stage of the pipeline"
  type = object({
    name     = string
    provider = string
  })
  default = {
    name     = "github-conn"
    provider = "GitHub"
  }
}
