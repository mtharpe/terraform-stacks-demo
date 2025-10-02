# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "workers_count" {
  type    = number
  default = "1"
}

variable "region" {
  type = string
}

variable "admin_user_arn" {
  description = "ARN of the AWS user or role to grant admin access to the EKS cluster"
  type        = string
}