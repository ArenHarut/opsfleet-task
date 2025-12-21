# ---------------------------------------------------------------------------------------------------------------------
# EKS CLUSTER MODULE CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "../../../../../terraform-modules/eks-karpenter/eks"
}

include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id          = "vpc-mock"
    private_subnets = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
  }
}

inputs = {
  vpc_id          = dependency.vpc.outputs.vpc_id
  subnet_ids      = dependency.vpc.outputs.private_subnets
  cluster_version = "1.32"
}