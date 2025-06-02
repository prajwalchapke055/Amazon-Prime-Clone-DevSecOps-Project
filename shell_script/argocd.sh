#!/bin/bash

# Set AWS credentials directly (for non-interactive use)
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"

# Update kubeconfig
aws eks update-kubeconfig --region "us-east-1" --name "amazon-prime-cluster"

# ArgoCD Access Info
argo_url=$(kubectl get svc -n argocd -o jsonpath="{.items[?(@.metadata.name=='argocd-server')].status.loadBalancer.ingress[0].hostname}")
argo_user="admin"
argo_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

# Output ArgoCD Credentials
echo "------------------------"
echo "ArgoCD URL: http://$argo_url"
echo "ArgoCD User: $argo_user"
echo "ArgoCD Password: $argo_password"
echo "------------------------"
