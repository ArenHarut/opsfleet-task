locals {
  environment = "production"

  tags = {
    Environment = "production"
    Terraform   = "true"
    Project     = "eks-karpenter"
  }
}