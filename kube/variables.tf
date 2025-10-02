# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  type        = string
}

variable "admin_user_arn" {
  description = "ARN of the AWS user or role to grant admin access to the EKS cluster"
  type        = string
}