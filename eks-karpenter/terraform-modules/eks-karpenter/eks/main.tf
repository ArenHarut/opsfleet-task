#------------------------------------------------------------------------------
# EKS Cluster Module
# Creates an EKS cluster with Fargate profiles for system workloads
#------------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.0"

  cluster_name    = var.environment
  cluster_version = var.cluster_version

  # Cluster endpoint access
  cluster_endpoint_public_access = true

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Cluster addons
  cluster_addons = {
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
        resources = {
          limits = {
            cpu    = "0.25"
            memory = "256M"
          }
          requests = {
            cpu    = "0.25"
            memory = "256M"
          }
        }
        tolerations = [
          {
            key      = "eks.amazonaws.com/compute-type"
            operator = "Equal"
            value    = "fargate"
            effect   = "NoSchedule"
          }
        ]
      })
    }
    kube-proxy = {}
    vpc-cni    = {}
  }

  # VPC configuration
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Let EKS module manage security groups
  create_cluster_security_group = true
  create_node_security_group    = true

  # Tag node security group for Karpenter discovery
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.environment
  }

  # Tags - include Karpenter discovery tag
  tags = merge(var.tags, {
    "karpenter.sh/discovery" = var.environment
  })

  # Fargate profiles for system workloads
  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]
    }
  }
}