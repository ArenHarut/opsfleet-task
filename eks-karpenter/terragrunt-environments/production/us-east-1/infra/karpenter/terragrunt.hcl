# ---------------------------------------------------------------------------------------------------------------------
# KARPENTER MODULE CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "../../../../../terraform-modules/eks-karpenter/karpenter"
}

include {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name      = "mock-cluster"
    cluster_endpoint  = "https://mock-endpoint.eks.amazonaws.com"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/mock"
  }
}

inputs = {
  cluster_name      = dependency.eks.outputs.cluster_name
  cluster_endpoint  = dependency.eks.outputs.cluster_endpoint
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
}
