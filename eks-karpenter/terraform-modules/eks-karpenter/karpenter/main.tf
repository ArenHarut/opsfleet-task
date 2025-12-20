#------------------------------------------------------------------------------
# Karpenter Module
# Deploys Karpenter controller with NodePool and EC2NodeClass
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Karpenter IAM Resources
#------------------------------------------------------------------------------

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.31.0"

  cluster_name = var.cluster_name

  # Enable v1 permissions for Karpenter 1.x
  enable_v1_permissions = true

  # Create IAM role for Karpenter controller
  create_iam_role = true

  # IRSA configuration
  enable_irsa                     = true
  irsa_oidc_provider_arn          = var.oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Additional policies for node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Karpenter Helm Release
#------------------------------------------------------------------------------

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.0.8"
  wait                = true
  wait_for_jobs       = true

  values = [
    <<-EOT
    settings:
      clusterName: ${var.cluster_name}
      clusterEndpoint: ${var.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    tolerations:
      - key: 'eks.amazonaws.com/compute-type'
        operator: Equal
        value: fargate
        effect: "NoSchedule"
    EOT
  ]

  depends_on = [module.karpenter]
}

#------------------------------------------------------------------------------
# Karpenter EC2NodeClass (v1 API)
# Defines how EC2 instances should be configured
#------------------------------------------------------------------------------

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.environment}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.environment}
      tags:
        karpenter.sh/discovery: ${var.environment}
        Name: "${var.environment}-karpenter-node"
  YAML

  depends_on = [helm_release.karpenter]
}

#------------------------------------------------------------------------------
# Karpenter NodePool (v1 API)
# Defines what instances Karpenter can provision
#------------------------------------------------------------------------------

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            # Instance categories (c=compute, m=general, r=memory, t=burstable)
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r", "t"]
            # Instance CPU sizes
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32"]
            # Architecture support - both x86 and ARM64 (Graviton)
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64", "arm64"]
            # Capacity type - prioritize Spot for cost savings
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot", "on-demand"]
          # Expire nodes after 720 hours (30 days) for security patching
          expireAfter: 720h
      # Resource limits for the node pool
      limits:
        cpu: 1000
        memory: 1000Gi
      # Disruption settings
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 1m
      # Weight for multi-pool scenarios (higher = more preferred)
      weight: 100
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}
