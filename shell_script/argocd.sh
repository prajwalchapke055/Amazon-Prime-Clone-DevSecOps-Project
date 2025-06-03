#!/bin/bash
set -e

# Set AWS credentials and region
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_DEFAULT_REGION="us-east-1"

echo "Updating kubeconfig for EKS cluster 'amazon-prime-cluster' in region $AWS_DEFAULT_REGION..."
aws eks update-kubeconfig --region "$AWS_DEFAULT_REGION" --name "amazon-prime-cluster"

# Get ArgoCD URL
argo_url=$(kubectl get svc -n argocd -o jsonpath="{.items[?(@.metadata.name=='argocd-server')].status.loadBalancer.ingress[0].hostname}")

if [ -z "$argo_url" ]; then
  echo "Error: ArgoCD server LoadBalancer hostname not found."
  exit 1
fi

argo_user="admin"
argo_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)

echo "------------------------"
echo "ArgoCD URL: http://$argo_url"
echo "ArgoCD User: $argo_user"
echo "ArgoCD Password: $argo_password"
echo "------------------------"
