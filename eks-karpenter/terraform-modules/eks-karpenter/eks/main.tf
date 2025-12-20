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

  # Use the provided security groups instead of creating new ones
  create_cluster_security_group = false
  create_node_security_group    = false

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

#------------------------------------------------------------------------------
# Security Group Rules for EKS Cluster to Karpenter Nodes Communication
#------------------------------------------------------------------------------

resource "aws_security_group_rule" "cluster_to_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = var.karpenter_node_security_group_id
  description              = "Allow EKS cluster to communicate with Karpenter nodes"
}

resource "aws_security_group_rule" "cluster_to_nodes_kubelet" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = module.eks.cluster_security_group_id
  security_group_id        = var.karpenter_node_security_group_id
  description              = "Allow EKS cluster to communicate with kubelet on Karpenter nodes"
}

resource "aws_security_group_rule" "nodes_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.karpenter_node_security_group_id
  security_group_id        = module.eks.cluster_security_group_id
  description              = "Allow Karpenter nodes to communicate with EKS cluster"
}
