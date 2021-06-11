variable "account_id" {
  description = "AWS account id used to create pipeline"
  type        = string
}

variable "common_tags" {
  description = "Tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "enabled" {
  description = "Determines if module should create resources or destroy pre-existing resources managed by this module"
  type        = bool
  default     = true
}

### CODEPIPELINE ###

variable "name" {
  description = "Pipeline name"
  type        = string
}

variable "stages" {
  description = "List of pipeline stages (see: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline)"
  type = list(object({
    name = string
    actions = list(object({
      name             = string
      category         = string
      owner            = string
      provider         = string
      version          = string
      configuration    = optional(map(string))
      input_artifacts  = optional(list(string))
      output_artifacts = optional(list(string))
      role_arn         = optional(string)
      run_order        = optional(number)
      region           = optional(string)
      namespace        = optional(string)
    }))
  }))
}

variable "pipeline_tags" {
  description = "Tags to attach to the CodePipeline"
  type        = map(string)
  default     = {}
}

variable "role_arn" {
  description = "Pre-existing IAM role ARN to use for the CodePipeline"
  type        = string
  default     = null
}

variable "cmk_arn" {
  description = "AWS KMS CMK (Customer Master Key) ARN used to encrypt Codepipeline artifacts"
  type        = string
  default     = null
}

### S3 ###

variable "artifact_bucket_name" {
  description = "AWS S3 bucket name used for storing Codepipeline artifacts"
  type        = string
  default     = null
}

variable "artifact_bucket_tags" {
  description = "Tags for AWS S3 bucket used to store pipeline artifacts"
  type        = map(string)
  default     = {}
}

variable "artifact_bucket_force_destroy" {
  description = "Determines if all bucket content will be deleted if the bucket is deleted (error-free bucket deletion)"
  type        = bool
  default     = false
}


#### CODEPIPELINE-IAM-ROLE ####

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
  description = "Tags to add to CodePipeline role"
  type        = map(string)
  default     = {}
}