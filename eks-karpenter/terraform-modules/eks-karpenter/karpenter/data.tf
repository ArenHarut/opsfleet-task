#------------------------------------------------------------------------------
# Data Sources for Karpenter
#------------------------------------------------------------------------------

# ECR Public authorization token (required for pulling Karpenter chart)
# Note: ECR Public is only available in us-east-1
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

# EKS cluster data
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}
