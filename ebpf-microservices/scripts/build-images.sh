#!/bin/bash

set -e

echo "Building Docker images..."

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo ""
echo "Building api-gateway..."
docker build -t api-gateway:latest ./api-gateway

echo ""
echo "Building user-service..."
docker build -t user-service:latest ./user-service

echo ""
echo "Building order-service..."
docker build -t order-service:latest ./order-service

echo ""
echo "Building load-generator..."
docker build -t load-generator:latest ./load-generator

echo ""
echo "All images built successfully!"
echo ""
docker images | grep -E "(api-gateway|user-service|order-service|load-generator)" || true
