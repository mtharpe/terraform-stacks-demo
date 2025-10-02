# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "cluster_url" {
  value = aws_eks_cluster.demo.endpoint
}

output "cluster_ca" {
  value = base64decode(aws_eks_cluster.demo.certificate_authority[0].data)
}

output "cluster_token" {
  sensitive = true
  value = data.aws_eks_cluster_auth.demo.token
}

output "node_group_role_arn" {
  value = aws_iam_role.demo-node.arn
}

output "admin_user_arn" {
  value = var.admin_user_arn
}
