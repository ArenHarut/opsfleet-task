module "eks" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v21.10.1"

  name               = "${local.resource_name_prefix}-eks"
  kubernetes_version = "1.33"

  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = true

  control_plane_scaling_config = {
    tier = "standard"
  }

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["t3a.large"]

      min_size     = 2
      max_size     = 4
      desired_size = 2

      labels = {
        "karpenter.sh/controller" = "true"
      }
    }
  }

  node_security_group_tags = merge(local.tags, {
    "karpenter.sh/discovery" = "${local.resource_name_prefix}-eks"
  })

  tags = local.tags
}
