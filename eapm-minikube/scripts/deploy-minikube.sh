#!/bin/bash

set -e

echo "Deploying to Minikube..."

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
  echo "Minikube is not running. Starting minikube..."
  minikube start
fi

echo ""
echo "Pulling required base images on host machine..."
# Pull postgres image on host (which has network access via Docker Desktop)
docker pull postgres:16-alpine

echo ""
echo "Building images on host machine..."
# Build on host machine (which has network access)
bash "$SCRIPT_DIR/build-images.sh"

echo ""
echo "Loading images into Minikube..."
# Load base images into minikube
minikube image load postgres:16-alpine

# Load application images into minikube
minikube image load api-gateway:latest
minikube image load user-service:latest
minikube image load order-service:latest
minikube image load load-generator:latest

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
echo "  minikube service api-gateway --url"
echo ""
echo "Or use port forwarding:"
echo "  kubectl port-forward service/api-gateway 8080:8080"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/api-gateway"
echo "  kubectl logs -f deployment/user-service"
echo "  kubectl logs -f deployment/order-service"
echo "  kubectl logs -f deployment/load-generator"
echo ""
echo "To view all pods:"
echo "  kubectl get pods"
