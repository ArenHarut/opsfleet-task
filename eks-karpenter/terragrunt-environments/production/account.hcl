# ---------------------------------------------------------------------------------------------------------------------
# ACCOUNT LEVEL VARIABLES
# Set these variables for your AWS account
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Account name - used for naming resources and state bucket
  account_name = "production"

  # Your AWS Account ID - REPLACE THIS with your actual account ID
  # You can find this by running: aws sts get-caller-identity --query Account --output text
  aws_account_id = "REPLACE_WITH_YOUR_AWS_ACCOUNT_ID"

  # AWS CLI profile name - REPLACE THIS with your profile name
  # Use "default" if you only have one profile configured
  aws_profile = "default"
}
