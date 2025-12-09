#!/bin/bash

set -e

echo "Cleaning up Kubernetes resources..."

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Delete Kubernetes resources
kubectl delete -f "$PROJECT_DIR/k8s/" --ignore-not-found=true

echo ""
echo "Cleaning up Docker images..."

# Check if we're using minikube
if kubectl config current-context | grep -q "minikube"; then
  echo "Detected Minikube environment"

  # Remove images from minikube
  echo "Removing application images from Minikube..."
  minikube image rm api-gateway:latest 2>/dev/null || echo "  api-gateway:latest not found in minikube"
  minikube image rm user-service:latest 2>/dev/null || echo "  user-service:latest not found in minikube"
  minikube image rm order-service:latest 2>/dev/null || echo "  order-service:latest not found in minikube"
  minikube image rm load-generator:latest 2>/dev/null || echo "  load-generator:latest not found in minikube"
  minikube image rm postgres:16-alpine 2>/dev/null || echo "  postgres:16-alpine not found in minikube"

  # Remove images from host Docker
  echo ""
  echo "Removing application images from host Docker..."
  docker rmi api-gateway:latest 2>/dev/null || echo "  api-gateway:latest not found on host"
  docker rmi user-service:latest 2>/dev/null || echo "  user-service:latest not found on host"
  docker rmi order-service:latest 2>/dev/null || echo "  order-service:latest not found on host"
  docker rmi load-generator:latest 2>/dev/null || echo "  load-generator:latest not found on host"

  # Optionally clean postgres from host (commented out by default)
  # docker rmi postgres:16-alpine 2>/dev/null || echo "  postgres:16-alpine not found on host"

else
  echo "Detected Rancher Desktop or Docker Desktop environment"

  # Remove images from Docker
  echo "Removing application images..."
  docker rmi api-gateway:latest 2>/dev/null || echo "  api-gateway:latest not found"
  docker rmi user-service:latest 2>/dev/null || echo "  user-service:latest not found"
  docker rmi order-service:latest 2>/dev/null || echo "  order-service:latest not found"
  docker rmi load-generator:latest 2>/dev/null || echo "  load-generator:latest not found"

  # Optionally clean postgres (commented out by default)
  # docker rmi postgres:16-alpine 2>/dev/null || echo "  postgres:16-alpine not found"
fi

echo ""
echo "Pruning dangling images..."
docker image prune -f

echo ""
echo "Cleanup complete!"
