# Pins the Terraform CLI version and the AWS provider version.
# This matters because provider behaviour can change between major versions —
# pinning means `terraform init` always gets the same provider you tested with,
# rather than silently picking up a newer one that might behave differently.

terraform {
  required_version = ">= 1.16.0" # matches the CLI version you installed and confirmed

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # the "~>" means "5.x, but not 6.0" — safe minor/patch updates only
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}
