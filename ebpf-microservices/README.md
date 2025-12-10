# eBPF Demo Application

A sample microservices application for demonstrating New Relic's eBPF instrumentation capabilities. This application consists of multiple services orchestrated with Kubernetes and includes passive load generation for realistic traffic patterns.

## Architecture

This demo application includes:

- **API Gateway** (Rust/Actix-web) - Main entry point that routes requests to backend services
- **User Service** (Node.js/Express) - Manages user data with PostgreSQL
- **Order Service** (Node.js/Express) - Manages order data with PostgreSQL
- **PostgreSQL Database** - Shared data store for user and order services
- **Load Generator** (Node.js) - Generates passive traffic with two different user journey paths

### Service Communication

```
┌─────────────────┐
│  Load Generator │
└────────┬────────┘
         │
         v
┌─────────────────┐      ┌──────────────┐
│   API Gateway   │─────>│ User Service │
│   (Rust:8080)   │      │  (Node:3001) │
└────────┬────────┘      └──────┬───────┘
         │                      │
         │                      v
         │               ┌─────────────┐
         │               │  PostgreSQL │
         │               │   (5432)    │
         │               └─────────────┘
         │                      ^
         v                      │
┌─────────────────┐             │
│  Order Service  │─────────────┘
│   (Node:3002)   │
└─────────────────┘
```

## Prerequisites

Choose one of the following deployment environments:

### Kubernetes (Cloud Provider)
- Access to a Kubernetes cluster on a cloud provider (AWS EKS, Google GKE, Azure AKS, etc.)
- kubectl installed and configured to connect to your cluster
- Docker installed locally (for building and pushing images)
- Access to a container registry (Docker Hub, ECR, GCR, ACR, etc.)

### Docker Compose (Local Development)
- Docker installed (Docker Desktop or native Docker)
- docker-compose installed
- **System Requirements:**
  - CPU: 2-4 cores
  - Memory: 4-8 GB RAM
  - Disk: 10-20 GB free space

### Native Ubuntu (Local eBPF Testing)
- Ubuntu 20.04+ (or other Debian-based Linux)
- Sudo privileges
- Internet connection for package installation
- **System Requirements:**
  - CPU: 2-4 cores
  - Memory: 4-8 GB RAM
  - Disk: 10-20 GB free space (for dependencies and build artifacts)

## Quick Start

### For Kubernetes (Cloud Provider)

1. Configure your container registry:
```bash
# Set your container registry URL (replace with your registry)
export REGISTRY="your-registry.io/your-namespace"

# Examples:
# export REGISTRY="docker.io/your-username"
# export REGISTRY="123456789.dkr.ecr.us-east-1.amazonaws.com"
# export REGISTRY="gcr.io/your-project"
# export REGISTRY="your-registry.azurecr.io"
```

2. Build and push images:
```bash
# Build all images
./scripts/build-images.sh

# Tag images for your registry
docker tag api-gateway:latest $REGISTRY/api-gateway:latest
docker tag user-service:latest $REGISTRY/user-service:latest
docker tag order-service:latest $REGISTRY/order-service:latest
docker tag load-generator:latest $REGISTRY/load-generator:latest

# Push to your registry
docker push $REGISTRY/api-gateway:latest
docker push $REGISTRY/user-service:latest
docker push $REGISTRY/order-service:latest
docker push $REGISTRY/load-generator:latest
```

3. Update the Kubernetes manifests with your registry:
```bash
# Update image references in the deployment files
sed -i '' "s|image: api-gateway:latest|image: $REGISTRY/api-gateway:latest|g" k8s/api-gateway-deployment.yaml
sed -i '' "s|image: user-service:latest|image: $REGISTRY/user-service:latest|g" k8s/user-service-deployment.yaml
sed -i '' "s|image: order-service:latest|image: $REGISTRY/order-service:latest|g" k8s/order-service-deployment.yaml
sed -i '' "s|image: load-generator:latest|image: $REGISTRY/load-generator:latest|g" k8s/load-generator-deployment.yaml
```

4. Deploy to your cluster:
```bash
# Ensure kubectl is configured for your cluster
kubectl cluster-info

# Apply all Kubernetes manifests
kubectl apply -f k8s/

# Wait for deployments to be ready
kubectl wait --for=condition=available --timeout=300s deployment/postgres
kubectl wait --for=condition=available --timeout=300s deployment/user-service
kubectl wait --for=condition=available --timeout=300s deployment/order-service
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway
kubectl wait --for=condition=available --timeout=300s deployment/load-generator
```

5. Access the API gateway:
```bash
# Use port forwarding
kubectl port-forward service/api-gateway 8080:8080

# Or expose via LoadBalancer (cloud providers)
kubectl patch service api-gateway -p '{"spec":{"type":"LoadBalancer"}}'
kubectl get service api-gateway  # Get the external IP
```

### For Docker Compose

1. Build and start all services:
```bash
docker-compose up --build -d
```

This will:
- Build all container images
- Create a Docker network for service communication
- Start PostgreSQL, user-service, order-service, api-gateway, and load-generator
- Expose the API gateway on port 8080

2. View logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api-gateway
```

3. Access the API gateway:
```bash
curl http://localhost:8080/health
```

4. Stop all services:
```bash
docker-compose down

# To also remove volumes
docker-compose down -v
```

### For Native Ubuntu

1. Run the deployment script:
```bash
./scripts/deploy-native-ubuntu.sh
```

This script will:
- Install Node.js, Rust, PostgreSQL, and build dependencies
- Set up the PostgreSQL database and user
- Build the Rust api-gateway
- Install npm dependencies for all Node.js services
- Create systemd user service files
- Start all services

2. Check service status:
```bash
systemctl --user status eapm-api-gateway
systemctl --user status eapm-user-service
systemctl --user status eapm-order-service
systemctl --user status eapm-load-generator
```

3. View logs:
```bash
# Real-time logs
journalctl --user -u eapm-api-gateway -f

# All logs for a service
journalctl --user -u eapm-user-service
```

4. Access the API gateway:
```bash
curl http://localhost:8080/health
```

5. Stop all services:
```bash
systemctl --user stop eapm-api-gateway eapm-user-service eapm-order-service eapm-load-generator
```

6. Complete cleanup:
```bash
./scripts/cleanup-native-ubuntu.sh
```

## eBPF Observability

This application is designed to demonstrate eBPF-based observability. Different deployment methods provide varying levels of eBPF visibility:

### Kubernetes (Cloud Provider)
- ✅ **Pod-to-pod network traffic**: eBPF can monitor all inter-service communication
- ✅ **Syscalls and process tracing**: Full visibility into container processes
- ✅ **HTTP request/response monitoring**: Can trace API calls between services
- 📊 **Production deployment for eBPF tools**: New Relic, Pixie, Cilium, etc.
- 🌐 **Real cloud environment**: Most representative of production scenarios

### Docker Compose
- ✅ **Container network traffic**: eBPF can monitor bridge/veth networking
- ✅ **Syscalls and process tracing**: Full visibility with minimal overhead
- ✅ **HTTP request/response monitoring**: Complete observability of service interactions
- 📊 **Well-supported by eBPF tools**: Works with most eBPF-based APM solutions
- ⚡ **Lighter weight than Kubernetes**: Less overhead, easier local development

### Native Ubuntu Processes
- ✅ **Maximum eBPF visibility**: No container abstraction layer
- ✅ **Direct kernel access**: Most efficient tracing possible
- ✅ **Network socket monitoring**: Direct visibility into TCP/HTTP traffic
- 📊 **Best for eBPF development**: Ideal for testing eBPF programs
- ⚡ **Lowest overhead**: No Docker or Kubernetes networking layers

**Key Point**: All three deployment methods on Linux provide full eBPF observability. The choice depends on your use case:
- **Kubernetes**: Production environment with cloud infrastructure
- **Docker Compose**: Quick local testing and development
- **Native processes**: Maximum performance and eBPF visibility for testing

## API Endpoints

Once deployed, the following endpoints are available:

### Health Check
```bash
curl http://localhost:8080/health
```

### Users
```bash
# Get all users
curl http://localhost:8080/users

# Get specific user
curl http://localhost:8080/users/1
```

### Orders
```bash
# Get all orders
curl http://localhost:8080/orders

# Create an order
curl -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product": "Laptop", "amount": 999.99}'
```

## Load Generator

The load generator automatically creates traffic through the system with two different journey paths:

### Path 1: Browse and Order (Even iterations)
1. Fetch all users
2. Fetch a specific user
3. Fetch all orders
4. Create a new order

### Path 2: Admin View (Odd iterations)
1. Fetch all orders
2. Fetch all users
3. Fetch a specific user

The load generator runs continuously with a 5-second interval between iterations and includes a 30-second startup delay to allow all services to be ready.

## Monitoring

### View Pod Status
```bash
kubectl get pods
```

### View Logs

API Gateway:
```bash
kubectl logs -f deployment/api-gateway
```

User Service:
```bash
kubectl logs -f deployment/user-service
```

Order Service:
```bash
kubectl logs -f deployment/order-service
```

Load Generator:
```bash
kubectl logs -f deployment/load-generator
```

Database:
```bash
kubectl logs -f deployment/postgres
```

### View All Services
```bash
kubectl get services
```

## Installing New Relic eBPF Instrumentation

This application is designed to easily accept New Relic's eBPF instrumentation.

### For Kubernetes Deployments

**Prerequisites:**
- Helm 3 installed (check with `helm version`)
- New Relic account and license key

For complete installation instructions, please refer to the official documentation:

[New Relic eBPF Kubernetes Installation Guide](https://docs.newrelic.com/docs/ebpf/k8s-installation/)

The eBPF instrumentation will automatically discover and monitor all services in the cluster once installed.

### For Host-Based Deployments (Docker Compose or Native Ubuntu)

For Docker Compose or native Ubuntu deployments, use the host-based installation method:

[New Relic eBPF Linux/Host Installation Guide](https://docs.newrelic.com/docs/ebpf/linux-installation/)

This method installs the eBPF agent directly on the host system and monitors all processes and network traffic.

**Note:** Ensure your VM meets the system requirements listed in the Prerequisites section (2-4 CPU cores, 4-8 GB RAM, 10-20 GB disk space) to run both the application and the eBPF agent.

## Cleanup

### Kubernetes (Cloud Provider)

To remove all deployed resources:

```bash
# Delete all Kubernetes resources
kubectl delete -f k8s/

# Optionally, remove images from your local machine
docker rmi api-gateway:latest
docker rmi user-service:latest
docker rmi order-service:latest
docker rmi load-generator:latest

# Clean up dangling images
docker image prune -f
```

**Note:** Images in your container registry will need to be removed separately using your registry's management tools.

### Docker Compose

To stop and remove all containers and networks:

```bash
docker-compose down

# To also remove volumes (database data)
docker-compose down -v

# To also remove images
docker-compose down --rmi all
```

### Native Ubuntu

To stop services and clean up:

```bash
./scripts/cleanup-native-ubuntu.sh
```

This script will:
- Stop and disable all systemd services
- Remove systemd service files
- Clean build artifacts (Rust target/, Node.js node_modules/)
- Optionally remove the PostgreSQL database

**Note:** System packages (Node.js, Rust, PostgreSQL) are preserved and must be removed manually if desired.

## Troubleshooting

### Services not starting
Check pod status and logs:
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Database connection issues
The user-service and order-service wait up to 30 seconds for the database to be ready. If issues persist:
```bash
kubectl logs deployment/postgres
kubectl logs deployment/user-service
kubectl logs deployment/order-service
```

### Image pull errors
If your cluster cannot pull images from your registry:

1. **Verify registry authentication**: Ensure your cluster has the proper credentials
   ```bash
   # For Docker Hub
   kubectl create secret docker-registry regcred \
     --docker-server=https://index.docker.io/v1/ \
     --docker-username=<your-username> \
     --docker-password=<your-password> \
     --docker-email=<your-email>

   # For AWS ECR
   kubectl create secret docker-registry regcred \
     --docker-server=<aws-account-id>.dkr.ecr.<region>.amazonaws.com \
     --docker-username=AWS \
     --docker-password=$(aws ecr get-login-password)

   # Add secret to service account
   kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}'
   ```

2. **Verify images are pushed**: Check that images exist in your registry
   ```bash
   docker images | grep api-gateway
   docker images | grep user-service
   docker images | grep order-service
   docker images | grep load-generator
   ```

3. **Check image references**: Ensure deployment files reference the correct registry
   ```bash
   grep "image:" k8s/*-deployment.yaml
   ```

### Port conflicts
If port 8080 is already in use locally, you can modify the port forwarding:
```bash
kubectl port-forward service/api-gateway 8081:8080
```

## Development

### Building Images Manually

```bash
# Build all images
./scripts/build-images.sh

# Or build individually
docker build -t api-gateway:latest ./api-gateway
docker build -t user-service:latest ./user-service
docker build -t order-service:latest ./order-service
docker build -t load-generator:latest ./load-generator
```

### Modifying Services

After making changes to any service:

```bash
# Build the updated image
docker build -t <service-name>:latest ./<service-name>

# Tag for your registry
docker tag <service-name>:latest $REGISTRY/<service-name>:latest

# Push to registry
docker push $REGISTRY/<service-name>:latest

# Update the deployment (triggers rolling update)
kubectl rollout restart deployment/<service-name>

# Monitor the rollout
kubectl rollout status deployment/<service-name>
```

### Load Generator Configuration

The load generator can be configured via environment variables in `k8s/load-generator-deployment.yaml`:

- `API_GATEWAY_URL`: URL of the API gateway (default: http://api-gateway:8080)
- `REQUEST_INTERVAL`: Milliseconds between iterations (default: 5000)
- `ENABLE_CREATES`: Enable POST requests to create orders (default: true)

## Project Structure

```
ebpf-microservices/
├── api-gateway/          # Rust API gateway service
│   ├── src/
│   ├── Cargo.toml
│   └── Dockerfile
├── user-service/         # Node.js user service
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── order-service/        # Node.js order service
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── load-generator/       # Node.js load generator
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── k8s/                  # Kubernetes manifests
│   ├── postgres-*.yaml
│   ├── user-service-*.yaml
│   ├── order-service-*.yaml
│   ├── api-gateway-*.yaml
│   └── load-generator-deployment.yaml
├── scripts/              # Deployment scripts
│   ├── build-images.sh
│   ├── deploy-native-ubuntu.sh
│   └── cleanup-native-ubuntu.sh
├── docker-compose.yml    # Docker Compose configuration
└── README.md
```
