# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Root configuration that all child modules inherit from
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Automatically load region-level variables
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract the variables we need for easy access
  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.aws_account_id
  aws_profile  = local.account_vars.locals.aws_profile
  aws_region   = local.region_vars.locals.aws_region
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "${local.aws_region}"
  profile = "${local.aws_profile}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.account_id}"]

  default_tags {
    tags = {
      Terraform   = "true"
      Environment = "${local.account_name}"
    }
  }
}
EOF
}

# Configure Terragrunt to store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    profile        = local.aws_profile
    encrypt        = true
    bucket         = "terraform-state-${local.account_id}-${local.aws_region}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "terraform-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder
# ---------------------------------------------------------------------------------------------------------------------

inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
  local.environment_vars.locals
)
