#!/bin/bash

set -e

echo "========================================="
echo "eBPF Native Ubuntu Deployment"
echo "========================================="
echo ""

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "This script should NOT be run as root (don't use sudo)"
   echo "It will prompt for sudo password when needed"
   exit 1
fi

echo "Step 1: Installing system dependencies..."
echo "This will require sudo privileges"
echo ""

# Update package lists
sudo apt-get update

# Install PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "Installing PostgreSQL..."
    sudo apt-get install -y postgresql postgresql-contrib
else
    echo "PostgreSQL already installed"
fi

# Install Node.js (if not present)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js already installed ($(node --version))"
fi

# Install Rust (if not present)
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "Rust already installed ($(rustc --version))"
fi

# Install build dependencies for Rust
echo "Installing build dependencies..."
sudo apt-get install -y build-essential pkg-config libssl-dev

echo ""
echo "Step 2: Setting up PostgreSQL database..."
echo ""

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database user and database
sudo -u postgres psql << EOF
-- Drop existing user and database if they exist
DROP DATABASE IF EXISTS appdb;
DROP USER IF EXISTS appuser;

-- Create new user and database
CREATE USER appuser WITH PASSWORD 'apppassword';
CREATE DATABASE appdb OWNER appuser;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE appdb TO appuser;
EOF

echo "PostgreSQL database 'appdb' and user 'appuser' created"

echo ""
echo "Step 3: Building services..."
echo ""

# Build Rust API Gateway
echo "Building api-gateway (Rust)..."
cd "$PROJECT_DIR/api-gateway"
cargo build --release
echo "✓ api-gateway built"

# Install Node.js dependencies for user-service
echo ""
echo "Installing user-service dependencies..."
cd "$PROJECT_DIR/user-service"
npm install
echo "✓ user-service dependencies installed"

# Install Node.js dependencies for order-service
echo ""
echo "Installing order-service dependencies..."
cd "$PROJECT_DIR/order-service"
npm install
echo "✓ order-service dependencies installed"

# Install Node.js dependencies for load-generator
echo ""
echo "Installing load-generator dependencies..."
cd "$PROJECT_DIR/load-generator"
npm install
echo "✓ load-generator dependencies installed"

echo ""
echo "Step 4: Creating systemd service files..."
echo ""

# Create systemd service directory for user services
mkdir -p "$HOME/.config/systemd/user"

# API Gateway service
cat > "$HOME/.config/systemd/user/eapm-api-gateway.service" << EOF
[Unit]
Description=eBPF API Gateway
After=network.target eapm-user-service.service eapm-order-service.service
Wants=eapm-user-service.service eapm-order-service.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR/api-gateway
ExecStart=$PROJECT_DIR/api-gateway/target/release/api-gateway
Restart=always
RestartSec=10
Environment="PORT=8080"
Environment="RUST_LOG=info"
Environment="USER_SERVICE_URL=http://localhost:3001"
Environment="ORDER_SERVICE_URL=http://localhost:3002"

[Install]
WantedBy=default.target
EOF

# User Service
cat > "$HOME/.config/systemd/user/eapm-user-service.service" << EOF
[Unit]
Description=eBPF User Service
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR/user-service
ExecStart=/usr/bin/node $PROJECT_DIR/user-service/index.js
Restart=always
RestartSec=10
Environment="PORT=3001"
Environment="DB_HOST=localhost"
Environment="DB_PORT=5432"
Environment="DB_NAME=appdb"
Environment="DB_USER=appuser"
Environment="DB_PASSWORD=apppassword"

[Install]
WantedBy=default.target
EOF

# Order Service
cat > "$HOME/.config/systemd/user/eapm-order-service.service" << EOF
[Unit]
Description=eBPF Order Service
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR/order-service
ExecStart=/usr/bin/node $PROJECT_DIR/order-service/index.js
Restart=always
RestartSec=10
Environment="PORT=3002"
Environment="DB_HOST=localhost"
Environment="DB_PORT=5432"
Environment="DB_NAME=appdb"
Environment="DB_USER=appuser"
Environment="DB_PASSWORD=apppassword"

[Install]
WantedBy=default.target
EOF

# Load Generator
cat > "$HOME/.config/systemd/user/eapm-load-generator.service" << EOF
[Unit]
Description=eBPF Load Generator
After=network.target eapm-api-gateway.service
Wants=eapm-api-gateway.service

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR/load-generator
ExecStart=/usr/bin/node $PROJECT_DIR/load-generator/index.js
Restart=always
RestartSec=10
Environment="API_GATEWAY_URL=http://localhost:8080"
Environment="REQUEST_INTERVAL=5000"
Environment="ENABLE_CREATES=true"

[Install]
WantedBy=default.target
EOF

echo "✓ Systemd service files created"

echo ""
echo "Step 5: Starting services..."
echo ""

# Reload systemd user daemon
systemctl --user daemon-reload

# Enable linger so services start on boot
sudo loginctl enable-linger $USER

# Start services in order
echo "Starting user-service..."
systemctl --user start eapm-user-service
systemctl --user enable eapm-user-service

echo "Starting order-service..."
systemctl --user start eapm-order-service
systemctl --user enable eapm-order-service

# Wait a bit for services to initialize
sleep 5

echo "Starting api-gateway..."
systemctl --user start eapm-api-gateway
systemctl --user enable eapm-api-gateway

# Wait a bit for api-gateway to start
sleep 3

echo "Starting load-generator..."
systemctl --user start eapm-load-generator
systemctl --user enable eapm-load-generator

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Services Status:"
echo "----------------"
systemctl --user status eapm-user-service --no-pager | head -3
systemctl --user status eapm-order-service --no-pager | head -3
systemctl --user status eapm-api-gateway --no-pager | head -3
systemctl --user status eapm-load-generator --no-pager | head -3

echo ""
echo "API Gateway available at: http://localhost:8080"
echo ""
echo "Useful Commands:"
echo "----------------"
echo "Check service status:"
echo "  systemctl --user status eapm-api-gateway"
echo "  systemctl --user status eapm-user-service"
echo "  systemctl --user status eapm-order-service"
echo "  systemctl --user status eapm-load-generator"
echo ""
echo "View logs:"
echo "  journalctl --user -u eapm-api-gateway -f"
echo "  journalctl --user -u eapm-user-service -f"
echo "  journalctl --user -u eapm-order-service -f"
echo "  journalctl --user -u eapm-load-generator -f"
echo ""
echo "Stop all services:"
echo "  systemctl --user stop eapm-api-gateway eapm-user-service eapm-order-service eapm-load-generator"
echo ""
echo "Test the API:"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/users"
echo "  curl http://localhost:8080/orders"
echo ""
