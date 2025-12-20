#------------------------------------------------------------------------------
# VPC Module
# Creates a VPC with public and private subnets across multiple AZs
#------------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.16.0"

  name = var.environment
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # NAT Gateway for private subnet internet access
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  # DNS settings required for EKS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Disable database subnet group (not needed)
  create_database_subnet_group = false

  # Manage default security group
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # Tags
  tags = merge(var.tags, {
    Name = var.environment
  })

  # Private subnet tags for EKS and Karpenter
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.environment}"  = "shared"
    "karpenter.sh/discovery"                    = var.environment
  }

  # Public subnet tags for EKS load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb"                   = "1"
    "kubernetes.io/cluster/${var.environment}" = "shared"
  }
}

#------------------------------------------------------------------------------
# Security Group for Karpenter Nodes
# This security group is used by Karpenter-provisioned nodes
#------------------------------------------------------------------------------

resource "aws_security_group" "karpenter_nodes" {
  name        = "${var.environment}-karpenter-nodes"
  description = "Security group for Karpenter provisioned nodes"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.tags, {
    Name                         = "${var.environment}-karpenter-nodes"
    "karpenter.sh/discovery"     = var.environment
  })
}

# Allow all egress traffic
resource "aws_security_group_rule" "karpenter_nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.karpenter_nodes.id
  description       = "Allow all outbound traffic"
}

# Allow all traffic within the security group (node-to-node communication)
resource "aws_security_group_rule" "karpenter_nodes_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.karpenter_nodes.id
  description       = "Allow node-to-node communication"
}

# Allow traffic from VPC CIDR (for pod communication)
resource "aws_security_group_rule" "karpenter_nodes_vpc" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.cidr]
  security_group_id = aws_security_group.karpenter_nodes.id
  description       = "Allow all traffic from VPC"
}
