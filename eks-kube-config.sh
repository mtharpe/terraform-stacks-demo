#!/bin/bash

# Script to configure EKS access for your user
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

echo "Configuring access for cluster: $CLUSTER_NAME"

# Step 1: Check if cluster exists
echo "Checking if cluster exists..."
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "ERROR: Cluster $CLUSTER_NAME not found in region $REGION"
    exit 1
fi

# Step 2: Configure kubeconfig to use the deployment role (which has admin access)
echo "Configuring kubeconfig to use deployment role..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" --role-arn "$ROLE_ARN"

# Step 3: Verify we can access the cluster
echo "Verifying cluster access with role credentials..."
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Cannot access cluster with role credentials!"
    echo "Make sure you have permission to assume role: $ROLE_ARN"
    exit 1
fi

# Step 4: Get current aws-auth ConfigMap and add user
echo "Getting current aws-auth ConfigMap..."
if kubectl get configmap aws-auth -n kube-system >/dev/null 2>&1; then
    # Get current mapRoles to preserve them
    CURRENT_MAP_ROLES=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}')
    
    # Check if user already exists
    CURRENT_MAP_USERS=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapUsers}' 2>/dev/null || echo "")
    
    if echo "$CURRENT_MAP_USERS" | grep -q "$USER_ARN"; then
        echo "User $USER_ARN already exists in aws-auth ConfigMap!"
    else
        echo "Adding user to aws-auth ConfigMap while preserving existing roles..."
        
        # Apply the patch with both existing roles and new user
        kubectl patch configmap/aws-auth -n kube-system --patch "{
          \"data\": {
            \"mapRoles\": \"$CURRENT_MAP_ROLES\",
            \"mapUsers\": \"- userarn: $USER_ARN\\n  username: admin-user\\n  groups:\\n  - system:masters\"
          }
        }"
        
        if [ $? -eq 0 ]; then
            echo "Successfully added user to aws-auth ConfigMap!"
        else
            echo "Failed to update aws-auth ConfigMap. You may need to do this manually."
            exit 1
        fi
    fi
else
    echo "ERROR: aws-auth ConfigMap not found. This is unusual for EKS."
    exit 1
fi

# Step 5: Update kubeconfig to use your user credentials instead of role
echo "Switching kubeconfig to use your user credentials..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Step 6: Test access with user credentials
echo "Testing access with your user credentials..."
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