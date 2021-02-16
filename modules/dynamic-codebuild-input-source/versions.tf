terraform {
  required_version = ">= 0.14.5"
  experiments = [module_variable_optional_attrs]
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.23"
    }
  }
}