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
    vpc_id                           = "vpc-mock"
    private_subnets                  = ["subnet-mock1", "subnet-mock2", "subnet-mock3"]
    karpenter_node_security_group_id = "sg-mock"
  }
}

inputs = {
  vpc_id                           = dependency.vpc.outputs.vpc_id
  subnet_ids                       = dependency.vpc.outputs.private_subnets
  karpenter_node_security_group_id = dependency.vpc.outputs.karpenter_node_security_group_id
  cluster_version                  = "1.32"
}
