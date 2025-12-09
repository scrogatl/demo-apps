# EAPM Minikube Demo Application

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

Choose one of the following Kubernetes environments:

### Option 1: Minikube
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) installed
- Docker installed (Docker Desktop or native Docker)
- kubectl installed
- Host machine must have access to Docker Hub (for pulling base images like postgres)

### Option 2: Rancher Desktop
- [Rancher Desktop](https://rancherdesktop.io/) installed
- kubectl installed (comes with Rancher Desktop)

### Option 3: Docker Compose (Local Development)
- Docker installed (Docker Desktop or native Docker)
- docker-compose installed

### Option 4: Native Ubuntu (eBPF Optimized)
- Ubuntu 20.04+ (or other Debian-based Linux)
- Sudo privileges
- Internet connection for package installation

## Quick Start

### For Minikube

1. Start Minikube (if not already running):
```bash
minikube start
```

2. Deploy the application:
```bash
./scripts/deploy-minikube.sh
```

This script will:
- Pull required base images (postgres) on your host machine
- Build all application container images on your host machine
- Load all images into Minikube
- Apply all Kubernetes manifests
- Wait for all deployments to be ready

3. Access the API gateway:
```bash
# Get the service URL
minikube service api-gateway --url

# Or use port forwarding
kubectl port-forward service/api-gateway 8080:8080
```

### For Rancher Desktop

1. Ensure Rancher Desktop is running with Kubernetes enabled

2. Deploy the application:
```bash
./scripts/deploy-rancher.sh
```

This script will:
- Build all container images using nerdctl or docker
- Apply all Kubernetes manifests
- Wait for all deployments to be ready

3. Access the API gateway:
```bash
# Use port forwarding
kubectl port-forward service/api-gateway 8080:8080

# Or access directly via NodePort
curl http://localhost:30080/health
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

### Kubernetes (Minikube/Rancher Desktop)
- ✅ **Pod-to-pod network traffic**: eBPF can monitor all inter-service communication
- ✅ **Syscalls and process tracing**: Full visibility into container processes
- ✅ **HTTP request/response monitoring**: Can trace API calls between services
- 📊 **Standard deployment for eBPF tools**: New Relic, Pixie, Cilium, etc.

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
- **Kubernetes**: Production-like environment
- **Docker Compose**: Quick local testing
- **Native processes**: Maximum performance and eBPF visibility

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

This application is designed to easily accept New Relic's eBPF instrumentation via Helm chart.

### Prerequisites
- Helm 3 installed (check with `helm version`)
- New Relic account and license key

For complete installation instructions, please refer to the official documentation:

[New Relic eBPF Kubernetes Installation Guide](https://docs.newrelic.com/docs/ebpf/k8s-installation/)

The eBPF instrumentation will automatically discover and monitor all services in the cluster once installed.

## Cleanup

### Kubernetes (Minikube/Rancher Desktop)

To remove all deployed resources and images:

```bash
./scripts/cleanup.sh
```

This script will:
- Delete all Kubernetes resources (deployments, services, configmaps, secrets, PVCs)
- Remove application images from Minikube (if using Minikube)
- Remove application images from host Docker
- Prune dangling Docker images

**Note:** The postgres:16-alpine base image is removed from Minikube by default but kept on the host machine. To also remove it from your host, uncomment the relevant line in `scripts/cleanup.sh`.

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
For Minikube, if images are not found, rebuild and reload them:
```bash
# Pull base images on host machine
docker pull postgres:16-alpine

# Build application images on host machine
./scripts/build-images.sh

# Load all images into Minikube
minikube image load postgres:16-alpine
minikube image load api-gateway:latest
minikube image load user-service:latest
minikube image load order-service:latest
minikube image load load-generator:latest
```

Note: Minikube's internal Docker daemon may not have internet access depending on your network configuration. Building images on the host machine (which can access Docker Hub via Docker Desktop or direct Docker access) and loading them into Minikube avoids this issue.

For Rancher Desktop, images should be available automatically after building.

### Cannot access Docker Hub from host machine
If your host machine cannot access Docker Hub (e.g., corporate network restrictions), you have a few options:

1. **Use a machine with Docker Hub access**: Deploy from a personal machine or a VM that has internet access
2. **Use Rancher Desktop instead**: If eBPF requirements are not needed, Rancher Desktop may handle image pulls differently
3. **Pre-download images**: On a machine with access, save images and transfer them:
   ```bash
   # On machine with access
   docker pull postgres:16-alpine
   docker save postgres:16-alpine -o postgres.tar

   # Transfer postgres.tar to target machine, then:
   docker load -i postgres.tar
   minikube image load postgres:16-alpine
   ```

### Port conflicts
If port 8080 or 30080 is already in use, you can modify the port forwarding:
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

For Minikube:
```bash
# Build images on host
./scripts/build-images.sh

# Load updated images into Minikube
minikube image load <service-name>:latest

# Restart the deployment
kubectl rollout restart deployment/<service-name>
```

For Rancher Desktop:
```bash
./scripts/build-images.sh
kubectl rollout restart deployment/<service-name>
```

### Load Generator Configuration

The load generator can be configured via environment variables in `k8s/load-generator-deployment.yaml`:

- `API_GATEWAY_URL`: URL of the API gateway (default: http://api-gateway:8080)
- `REQUEST_INTERVAL`: Milliseconds between iterations (default: 5000)
- `ENABLE_CREATES`: Enable POST requests to create orders (default: true)

## Project Structure

```
eapm-minikube/
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
│   ├── deploy-minikube.sh
│   ├── deploy-rancher.sh
│   ├── deploy-native-ubuntu.sh
│   ├── cleanup.sh
│   └── cleanup-native-ubuntu.sh
├── docker-compose.yml    # Docker Compose configuration
└── README.md
```
