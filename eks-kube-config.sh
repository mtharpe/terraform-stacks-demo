#!/bin/bash

# Script to discover Terraform Stacks EKS clusters and configure local kubeconfig
# Usage: ./eks-kube-config.sh [cluster-suffix]

REGION="us-east-2"
CLUSTER_PREFIX="stacks-demo"

echo "🔍 Discovering Terraform Stacks EKS clusters..."

# Get all EKS clusters with our prefix
CLUSTERS=($(aws eks list-clusters --region "$REGION" --query "clusters[?starts_with(@, '$CLUSTER_PREFIX')]" --output text))

if [ ${#CLUSTERS[@]} -eq 0 ]; then
    echo "❌ No EKS clusters found with prefix '$CLUSTER_PREFIX' in region $REGION"
    exit 1
fi

echo "📋 Found ${#CLUSTERS[@]} cluster(s):"
for i in "${!CLUSTERS[@]}"; do
    CLUSTER_NAME="${CLUSTERS[$i]}"
    CLUSTER_STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.status' --output text)
    CLUSTER_VERSION=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.version' --output text)
    CREATED_DATE=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.createdAt' --output text)
    
    echo "  $((i+1)). $CLUSTER_NAME (Status: $CLUSTER_STATUS, Version: $CLUSTER_VERSION, Created: $CREATED_DATE)"
done

# If specific cluster suffix provided, use it
if [ -n "$1" ]; then
    TARGET_CLUSTER="$CLUSTER_PREFIX-$1"
    
    # Check if the specified cluster exists in our list
    FOUND=false
    for cluster in "${CLUSTERS[@]}"; do
        if [ "$cluster" = "$TARGET_CLUSTER" ]; then
            FOUND=true
            break
        fi
    done
    
    if [ "$FOUND" = false ]; then
        echo "❌ Cluster '$TARGET_CLUSTER' not found"
        exit 1
    fi
    
    SELECTED_CLUSTER="$TARGET_CLUSTER"
else
    # Interactive selection if multiple clusters or no argument provided
    if [ ${#CLUSTERS[@]} -eq 1 ]; then
        SELECTED_CLUSTER="${CLUSTERS[0]}"
        echo "📌 Auto-selecting the only available cluster: $SELECTED_CLUSTER"
    else
        echo ""
        read -p "🎯 Select cluster number (1-${#CLUSTERS[@]}): " selection
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#CLUSTERS[@]} ]; then
            echo "❌ Invalid selection"
            exit 1
        fi
        
        SELECTED_CLUSTER="${CLUSTERS[$((selection-1))]}"
    fi
fi

echo ""
echo "🔗 Configuring kubeconfig for cluster: $SELECTED_CLUSTER"

# Update kubeconfig
aws eks update-kubeconfig --region "$REGION" --name "$SELECTED_CLUSTER" --alias "$SELECTED_CLUSTER"

if [ $? -eq 0 ]; then
    echo "✅ Successfully configured kubeconfig!"
    echo "📝 Context name: $SELECTED_CLUSTER"
    echo ""
    
    # Test connection
    echo "🧪 Testing connection..."
    if kubectl get nodes --context "$SELECTED_CLUSTER" >/dev/null 2>&1; then
        echo "🎉 SUCCESS! Connected to cluster $SELECTED_CLUSTER"
        echo ""
        echo "📊 Cluster nodes:"
        kubectl get nodes --context "$SELECTED_CLUSTER"
        echo ""
        echo "🔧 To use this cluster:"
        echo "   kubectl --context $SELECTED_CLUSTER get nodes"
        echo "   # or switch context:"
        echo "   kubectl config use-context $SELECTED_CLUSTER"
    else
        echo "⚠️  kubeconfig updated but connection test failed."
        echo "💡 This likely means you don't have access to the cluster yet."
        echo "   Make sure your user is added to the aws-auth ConfigMap via Terraform Stacks deployment."
    fi
else
    echo "❌ Failed to update kubeconfig"
    exit 1
fi