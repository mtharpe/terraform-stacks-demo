#/bin/bash
aws eks --region us-east-2 update-kubeconfig --name $1 --alias stacks-demo
