#!/bin/bash

set -e

echo "Deploying to Rancher Desktop..."

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if kubectl is configured for Rancher Desktop
if ! kubectl cluster-info > /dev/null 2>&1; then
  echo "Error: kubectl is not configured or cluster is not accessible"
  echo "Please ensure Rancher Desktop is running and kubectl is configured"
  exit 1
fi

echo ""
echo "Current context: $(kubectl config current-context)"
echo ""

# Rancher Desktop can use either docker or nerdctl
# Prefer docker if available as it's more straightforward
if command -v docker &> /dev/null && docker info > /dev/null 2>&1; then
  echo "Using docker"
  CONTAINER_CMD="docker"
  BUILD_CMD="docker build"
elif command -v nerdctl &> /dev/null; then
  echo "Using nerdctl (Rancher Desktop's container runtime)"
  echo "Building in k8s.io namespace for Kubernetes access..."
  CONTAINER_CMD="nerdctl"
  # Use k8s.io namespace so Kubernetes can access the images
  BUILD_CMD="nerdctl --namespace k8s.io build"
else
  echo "Error: Neither docker nor nerdctl found"
  echo "Please ensure Rancher Desktop is properly installed and the container runtime is enabled"
  exit 1
fi

echo ""
echo "Building images..."

cd "$PROJECT_DIR"

echo ""
echo "Building api-gateway..."
$BUILD_CMD -t api-gateway:latest ./api-gateway

echo ""
echo "Building user-service..."
$BUILD_CMD -t user-service:latest ./user-service

echo ""
echo "Building order-service..."
$BUILD_CMD -t order-service:latest ./order-service

echo ""
echo "Building load-generator..."
$BUILD_CMD -t load-generator:latest ./load-generator

echo ""
echo "Applying Kubernetes manifests..."
kubectl apply -f "$PROJECT_DIR/k8s/"

echo ""
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres || true
kubectl wait --for=condition=available --timeout=300s deployment/user-service || true
kubectl wait --for=condition=available --timeout=300s deployment/order-service || true
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway || true
kubectl wait --for=condition=available --timeout=300s deployment/load-generator || true

echo ""
echo "Deployment complete!"
echo ""
echo "To access the API gateway:"
echo "  kubectl port-forward service/api-gateway 8080:8080"
echo ""
echo "Or access via NodePort on localhost:30080"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/api-gateway"
echo "  kubectl logs -f deployment/user-service"
echo "  kubectl logs -f deployment/order-service"
echo "  kubectl logs -f deployment/load-generator"
echo ""
echo "To view all pods:"
echo "  kubectl get pods"
