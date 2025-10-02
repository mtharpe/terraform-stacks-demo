# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

component "cluster" {
  source = "./cluster"

  providers = {
    aws = provider.aws.main
    random = provider.random.main
  }

  inputs = {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    region             = var.region
    admin_user_arn     = var.admin_user_arn
  }
}

component "kube" {
  source = "./kube"

  providers = {
    kubernetes = provider.kubernetes.main
  }
}
