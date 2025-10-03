# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32.0"
    }
  }
}

resource "kubernetes_namespace_v1" "demo_ns" {
  metadata {
    name = "demo-ns"
  }
}

resource "kubernetes_manifest" "demo_workspace" {
  manifest = {
    apiVersion = "app.terraform.io/v1alpha2"
    kind       = kubernetes_manifest.crd_workspaces.object.spec.names.kind
    metadata = {
      name      = "deferred-demo"
      namespace = kubernetes_namespace_v1.demo_ns.id
    }
    spec = {
      name         = "demo-ws"
      organization = "demo-org"
      token = {
        secretKeyRef = {
          name = "demo-token"
          key  = "token"
        }
      }
    }
  }
}

# Patch the aws-auth ConfigMap to add admin user access
# This preserves the node roles that EKS creates automatically
resource "kubernetes_config_map_v1_data" "aws_auth_users" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  
  data = {
    mapUsers = yamlencode([
      {
        userarn  = var.admin_user_arn
        username = "admin-user"
        groups   = ["system:masters"]
      }
    ])
  }
  
  # This resource patches existing data without overwriting mapRoles
  force = true
}