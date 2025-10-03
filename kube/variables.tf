# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "admin_user_arn" {
  description = "ARN of the AWS user to grant admin access to the EKS cluster"
  type        = string
}