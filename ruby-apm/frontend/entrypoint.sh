#!/bin/bash
# frontend/entrypoint.sh
set -e # Exit immediately if a command exits with a non-zero status.

echo "Frontend entrypoint script started..."

# Set the working directory (redundant if WORKDIR is set in Dockerfile, but safe)
cd /frontend
echo "Current directory: $(pwd)"

# Create the tmp/pids directory if it doesn't exist.
# This is needed for Puma to write its pidfile.
mkdir -p tmp/pids
echo "Ensured tmp/pids directory exists."

# Remove a potentially pre-existing server.pid for Rails.
# This prevents errors if the container was stopped uncleanly.
if [ -f tmp/pids/server.pid ]; then
  echo "Removing existing server.pid..."
  rm tmp/pids/server.pid
fi

# Add a small delay - sometimes helps with race conditions on startup
echo "Waiting 3 seconds before starting Puma..."
sleep 3

echo "Starting Rails server (Frontend) via Puma command: $@"
# Then exec the container's main process (what's set as CMD in the Dockerfile).
# Using 'exec' means Puma replaces the script process, becoming PID 1 in the container.
exec "$@"

# This line should not be reached if exec works
echo "ERROR: exec command failed!"
exit 1
