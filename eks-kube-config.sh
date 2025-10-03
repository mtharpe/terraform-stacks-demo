#!/bin/bash

# Script to configure EKS access for your user WITHOUT breaking Terraform Stacks OIDC
# Usage: ./eks-kube-config.sh <cluster-suffix>

if [ -z "$1" ]; then
    echo "Usage: $0 <cluster-suffix>"
    echo "Example: $0 a1b2 (for cluster stacks-demo-a1b2)"
    exit 1
fi

CLUSTER_NAME="stacks-demo-$1"
REGION="us-east-2"
USER_ARN="arn:aws:iam::625172872027:user/tharpem"
ROLE_ARN="arn:aws:iam::625172872027:role/stacks-Axis-Personal-AWS"

echo "Configuring EKS access for user without breaking Terraform Stacks OIDC..."
echo "Cluster: $CLUSTER_NAME"

# Step 1: Check if cluster exists
echo "Checking if cluster exists..."
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "ERROR: Cluster $CLUSTER_NAME not found in region $REGION"
    exit 1
fi

# Step 2: Check current authentication mode
AUTH_MODE=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.accessConfig.authenticationMode' --output text 2>/dev/null || echo "CONFIG_MAP")
echo "Current authentication mode: $AUTH_MODE"

if [ "$AUTH_MODE" = "API" ] || [ "$AUTH_MODE" = "API_AND_CONFIG_MAP" ]; then
    echo "Using EKS Access Entry API (newer method)..."
    
    # Check if access entry already exists
    if aws eks describe-access-entry --cluster-name "$CLUSTER_NAME" --principal-arn "$USER_ARN" --region "$REGION" >/dev/null 2>&1; then
        echo "Access entry already exists for user: $USER_ARN"
    else
        echo "Creating access entry for user..."
        aws eks create-access-entry \
            --cluster-name "$CLUSTER_NAME" \
            --principal-arn "$USER_ARN" \
            --region "$REGION"
            
        echo "Associating admin policy..."
        aws eks associate-access-policy \
            --cluster-name "$CLUSTER_NAME" \
            --principal-arn "$USER_ARN" \
            --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
            --access-scope type=cluster \
            --region "$REGION"
    fi
    
else
    echo "Using CONFIG_MAP authentication mode (older method)..."
    echo ""
    echo "⚠️  MANUAL STEP REQUIRED:"
    echo "Since this cluster uses CONFIG_MAP authentication and we don't want to break"
    echo "the Terraform Stacks OIDC setup, you need to manually add your user to the"
    echo "aws-auth ConfigMap from within HCP Terraform or ask someone with admin access."
    echo ""
    echo "Option 1: Add this to your Terraform configuration and redeploy:"
    echo "---"
    echo "resource \"kubernetes_config_map\" \"aws_auth_patch\" {"
    echo "  metadata {"
    echo "    name      = \"aws-auth\""
    echo "    namespace = \"kube-system\""
    echo "  }"
    echo ""
    echo "  data = {"
    echo "    mapUsers = yamlencode(["
    echo "      {"
    echo "        userarn  = \"$USER_ARN\""
    echo "        username = \"admin-user\""
    echo "        groups = [\"system:masters\"]"
    echo "      }"
    echo "    ])"
    echo "  }"
    echo ""
    echo "  lifecycle {"
    echo "    ignore_changes = [data[\"mapRoles\"]]"
    echo "  }"
    echo "}"
    echo "---"
    echo ""
    echo "Option 2: Ask someone with cluster admin access to run:"
    echo "kubectl patch configmap/aws-auth -n kube-system --patch '{"
    echo "  \"data\": {"
    echo "    \"mapUsers\": \"- userarn: $USER_ARN\\n  username: admin-user\\n  groups:\\n  - system:masters\""
    echo "  }"
    echo "}'"
    echo ""
    exit 0
fi

# Step 3: Configure kubeconfig for your user (not the role)
echo "Configuring kubeconfig for your user..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Step 4: Test access
echo "Testing access..."
sleep 5  # Wait a moment for changes to propagate
if kubectl get nodes >/dev/null 2>&1; then
    echo ""
    echo "🎉 SUCCESS! You now have admin access to the EKS cluster!"
    echo ""
    kubectl get nodes
    echo ""
    echo "You can now use kubectl commands with your user credentials."
else
    echo "⏳ Access test failed. Changes may take a moment to propagate."
    echo "Try running: kubectl get nodes"
fi
    
else
    echo "ERROR: Cannot assume role $ROLE_ARN"
    echo ""
    echo "SOLUTION 1: Ask someone with access to the role to run this command:"
    echo "kubectl patch configmap/aws-auth -n kube-system --patch '{\"data\":{\"mapUsers\":\"- userarn: $USER_ARN\\n  username: admin-user\\n  groups:\\n  - system:masters\\n\"}}'"
    echo ""
    echo "SOLUTION 2: Add assume role permission to your user with this policy:"
    echo "{"
    echo "    \"Version\": \"2012-10-17\","
    echo "    \"Statement\": ["
    echo "        {"
    echo "            \"Effect\": \"Allow\","
    echo "            \"Action\": \"sts:AssumeRole\","
    echo "            \"Resource\": \"$ROLE_ARN\""
    echo "        }"
    echo "    ]"
    echo "}"
    echo ""
    echo "SOLUTION 3: Update kubeconfig to always use the role (if you have access):"
    echo "aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME --role-arn $ROLE_ARN"
fi