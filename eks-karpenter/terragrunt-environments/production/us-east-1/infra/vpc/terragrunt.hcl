# ---------------------------------------------------------------------------------------------------------------------
# VPC MODULE CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "../../../../../terraform-modules/eks-karpenter/vpc"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  single_nat_gateway   = true  # Set to false for production HA
}
