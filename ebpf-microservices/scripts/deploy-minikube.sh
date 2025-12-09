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
echo "This may take a few minutes depending on image sizes..."

# Load base images into minikube
echo "  [1/5] Loading postgres:16-alpine..."
minikube image load postgres:16-alpine
echo "        ✓ postgres:16-alpine loaded"

# Load application images into minikube
echo "  [2/5] Loading api-gateway:latest..."
minikube image load api-gateway:latest
echo "        ✓ api-gateway:latest loaded"

echo "  [3/5] Loading user-service:latest..."
minikube image load user-service:latest
echo "        ✓ user-service:latest loaded"

echo "  [4/5] Loading order-service:latest..."
minikube image load order-service:latest
echo "        ✓ order-service:latest loaded"

echo "  [5/5] Loading load-generator:latest..."
minikube image load load-generator:latest
echo "        ✓ load-generator:latest loaded"

echo ""
echo "All images loaded successfully!"

echo ""
echo "Applying Kubernetes manifests..."
kubectl apply -f "$PROJECT_DIR/k8s/"

echo ""
echo "Waiting for deployments to be ready (up to 5 minutes per service)..."

echo "  [1/5] Waiting for postgres..."
kubectl wait --for=condition=available --timeout=300s deployment/postgres || echo "        ⚠ postgres timed out"

echo "  [2/5] Waiting for user-service..."
kubectl wait --for=condition=available --timeout=300s deployment/user-service || echo "        ⚠ user-service timed out"

echo "  [3/5] Waiting for order-service..."
kubectl wait --for=condition=available --timeout=300s deployment/order-service || echo "        ⚠ order-service timed out"

echo "  [4/5] Waiting for api-gateway..."
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway || echo "        ⚠ api-gateway timed out"

echo "  [5/5] Waiting for load-generator..."
kubectl wait --for=condition=available --timeout=300s deployment/load-generator || echo "        ⚠ load-generator timed out"

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
