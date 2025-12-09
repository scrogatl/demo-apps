#!/bin/bash

set -e

echo "========================================="
echo "EAPM Native Ubuntu Cleanup"
echo "========================================="
echo ""

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Step 1: Stopping systemd services..."
echo ""

# Stop and disable services
systemctl --user stop eapm-api-gateway 2>/dev/null || echo "  api-gateway not running"
systemctl --user stop eapm-user-service 2>/dev/null || echo "  user-service not running"
systemctl --user stop eapm-order-service 2>/dev/null || echo "  order-service not running"
systemctl --user stop eapm-load-generator 2>/dev/null || echo "  load-generator not running"

systemctl --user disable eapm-api-gateway 2>/dev/null || true
systemctl --user disable eapm-user-service 2>/dev/null || true
systemctl --user disable eapm-order-service 2>/dev/null || true
systemctl --user disable eapm-load-generator 2>/dev/null || true

echo "✓ Services stopped"

echo ""
echo "Step 2: Removing systemd service files..."
echo ""

# Remove service files
rm -f "$HOME/.config/systemd/user/eapm-api-gateway.service"
rm -f "$HOME/.config/systemd/user/eapm-user-service.service"
rm -f "$HOME/.config/systemd/user/eapm-order-service.service"
rm -f "$HOME/.config/systemd/user/eapm-load-generator.service"

# Reload systemd
systemctl --user daemon-reload

echo "✓ Service files removed"

echo ""
echo "Step 3: Cleaning up build artifacts..."
echo ""

# Clean Rust build
if [ -d "$PROJECT_DIR/api-gateway/target" ]; then
    rm -rf "$PROJECT_DIR/api-gateway/target"
    echo "  ✓ Removed api-gateway/target"
fi

# Clean Node.js dependencies
if [ -d "$PROJECT_DIR/user-service/node_modules" ]; then
    rm -rf "$PROJECT_DIR/user-service/node_modules"
    echo "  ✓ Removed user-service/node_modules"
fi

if [ -d "$PROJECT_DIR/order-service/node_modules" ]; then
    rm -rf "$PROJECT_DIR/order-service/node_modules"
    echo "  ✓ Removed order-service/node_modules"
fi

if [ -d "$PROJECT_DIR/load-generator/node_modules" ]; then
    rm -rf "$PROJECT_DIR/load-generator/node_modules"
    echo "  ✓ Removed load-generator/node_modules"
fi

echo ""
echo "Step 4: Database cleanup (optional)..."
echo ""
echo "Would you like to remove the PostgreSQL database? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS appdb;
DROP USER IF EXISTS appuser;
EOF
    echo "✓ Database removed"
else
    echo "  Database preserved"
fi

echo ""
echo "========================================="
echo "Cleanup Complete!"
echo "========================================="
echo ""
echo "Note: System packages (Node.js, Rust, PostgreSQL) were NOT removed."
echo "To remove them manually, run:"
echo "  sudo apt-get remove postgresql nodejs"
echo "  rustup self uninstall"
echo ""
