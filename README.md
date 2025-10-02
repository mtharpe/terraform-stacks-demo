# Terraform Stacks EKS Demo

This project demonstrates how to use [Terraform Stacks](https://developer.hashicorp.com/terraform/language/stacks) to deploy and manage an Amazon EKS cluster with Kubernetes workloads using deferred actions.

## Overview

This Terraform Stacks configuration creates:
- An Amazon EKS cluster with worker nodes
- VPC and networking infrastructure 
- A Kubernetes namespace and Custom Resource Definition (CRD) for Terraform workspaces
- A deferred Terraform workspace resource that can be managed through the Kubernetes API

The project showcases Terraform Stacks' ability to:
- Organize infrastructure into reusable components
- Use deferred actions for resources that depend on dynamic data
- Manage both cloud infrastructure and Kubernetes resources in a single stack

## Project Structure

```
.
├── components.tfstack.hcl      # Component definitions for the stack
├── deployments.tfdeploy.hcl    # Deployment configurations
├── providers.tfstack.hcl       # Provider configurations and requirements
├── variables.tfstack.hcl       # Stack-level variable definitions
├── cluster/                    # EKS cluster component
│   ├── main.tf                 # EKS cluster and node group resources
│   ├── vpc.tf                  # VPC, subnets, and networking
│   ├── iam.tf                  # IAM roles and policies for EKS
│   ├── variables.tf            # Component input variables
│   └── outputs.tf              # Component outputs (cluster info)
└── kube/                       # Kubernetes resources component
    ├── crd.tf                  # Custom Resource Definition for workspaces
    └── kube.tf                 # Kubernetes namespace and workspace manifest
```

### Components

- **cluster**: Creates the EKS cluster infrastructure including VPC, subnets, security groups, and IAM roles
- **kube**: Deploys Kubernetes resources including a CRD and a deferred workspace resource

### Stacks Configuration Files

- `components.tfstack.hcl`: Defines the two components and their provider/input mappings
- `deployments.tfdeploy.hcl`: Configures the "development" deployment with AWS authentication
- `providers.tfstack.hcl`: Sets up AWS and Kubernetes provider configurations
- `variables.tfstack.hcl`: Defines stack-level variables for cluster configuration

## Prerequisites

Before using this Terraform Stacks demo, you'll need:

### Tools Required

- **Terraform CLI** (v1.7.0 or later with Stacks support)
- **HCP Terraform account** (for Stacks execution)
- **AWS CLI** (configured with appropriate credentials)
- **kubectl** (for interacting with the EKS cluster)

### AWS Setup

1. **AWS Account** with permissions to create:
   - EKS clusters and node groups
   - VPC, subnets, security groups, and internet gateways
   - IAM roles and policies
   - EC2 instances (for worker nodes)

2. **IAM Role for HCP Terraform** with the following trust policy:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/app.terraform.io"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "app.terraform.io:aud": "aws.workload.identity"
           }
         }
       }
     ]
   }
   ```

3. **Attach the following AWS managed policies** to the role:
   - `AmazonEKSClusterPolicy`
   - `AmazonEKSWorkerNodePolicy` 
   - `AmazonEKS_CNI_Policy`
   - `AmazonEC2ContainerRegistryReadOnly`
   - `AmazonVPCFullAccess`
   - `IAMFullAccess` (or a more restrictive custom policy)

### HCP Terraform Configuration

1. **Create a new project** in HCP Terraform
2. **Enable dynamic provider credentials** for AWS in your project settings
3. **Configure the OIDC provider** in your AWS account to trust HCP Terraform

## Deployment Process

### 1. Configure the Deployment

Edit `deployments.tfdeploy.hcl` and update the following values:

```hcl
deployment "development" {
  inputs = {
    cluster_name        = "your-cluster-name"      # Change to your preferred name
    kubernetes_version  = "1.30"                   # Update to desired K8s version
    region              = "us-east-2"              # Change to your preferred region
    role_arn            = "<YOUR_ROLE_ARN>"        # Replace with your IAM role ARN
    identity_token      = identity_token.aws.jwt
    default_tags        = { 
      project = "terraform-stacks-demo"
      environment = "development"
    }
  }
}
```

### 2. Initialize and Deploy the Stack

```bash
# Initialize the Terraform configuration
terraform init

# Plan the deployment to review changes
terraform plan

# Apply the stack to create resources
terraform apply
```

### 3. Access the EKS Cluster

After successful deployment:

```bash
# Update your kubeconfig to access the cluster
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Verify cluster access
kubectl get nodes

# Check the deployed resources
kubectl get namespace
kubectl get crd workspaces.app.terraform.io
kubectl get workspace -n demo-ns
```

### 4. Verify Terraform Workspace CRD

The stack deploys a Custom Resource Definition and creates a workspace resource:

```bash
# View the CRD
kubectl describe crd workspaces.app.terraform.io

# Check the workspace resource (this will be deferred initially)
kubectl describe workspace deferred-demo -n demo-ns
```

## Cleanup

To destroy the resources and avoid ongoing AWS charges:

### 1. Destroy the Stack

```bash
# Destroy all resources created by the stack
terraform destroy
```

### 2. Verify Resource Cleanup

```bash
# Check that the EKS cluster has been deleted
aws eks list-clusters --region <your-region>

# Verify VPC and associated resources are cleaned up
aws ec2 describe-vpcs --region <your-region> --filters "Name=tag:stacks-preview-example,Values=eks-deferred-stack"
```

### 3. Clean up AWS IAM Role (Optional)

If you created a dedicated IAM role for this demo, you can delete it:

```bash
# Detach policies from the role
aws iam detach-role-policy --role-name <your-role-name> --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
# ... (repeat for other attached policies)

# Delete the role
aws iam delete-role --role-name <your-role-name>
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Ensure your IAM role has the correct trust policy and permissions
2. **Region Mismatches**: Verify the region in `deployments.tfdeploy.hcl` matches your AWS configuration
3. **Resource Limits**: Check AWS service limits for EKS clusters and EC2 instances in your account
4. **Network Issues**: Ensure your VPC CIDR blocks don't conflict with existing networks

### Getting Help

- [Terraform Stacks Documentation](https://developer.hashicorp.com/terraform/language/stacks)
- [HCP Terraform Documentation](https://developer.hashicorp.com/terraform/cloud-docs)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Reference Documents](https://developer.hashicorp.com/terraform/tutorials/cloud/stacks-eks-deferred) 

## License

This project is licensed under the Mozilla Public License 2.0 - see the LICENSE file for details.

