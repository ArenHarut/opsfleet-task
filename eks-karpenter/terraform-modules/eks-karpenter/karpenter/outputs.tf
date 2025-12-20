output "karpenter_iam_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Name of the IAM role for Karpenter nodes"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_node_iam_role_arn" {
  description = "ARN of the IAM role for Karpenter nodes"
  value       = module.karpenter.node_iam_role_arn
}

output "karpenter_queue_name" {
  description = "Name of the SQS queue for Karpenter interruption handling"
  value       = module.karpenter.queue_name
}
