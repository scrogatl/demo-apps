#!/bin/bash
set -e

# --- Configuration Passed from Terraform ---
PROJECT_PREFIX="${project_prefix}"
SQL_PASSWORD="${sql_password}"
NEW_RELIC_LICENSE_KEY="${new_relic_license_key}"
NEW_RELIC_TEAM_TAG="${new_relic_team_tag}"
NEW_RELIC_ENVIRONMENT_TAG="${new_relic_environment_tag}"

# --- Log Setup ---
LOG_FILE="/usr/src/app/startup-script.log"
# The double $$ is here to make sure it's not looking for a TF var
exec > >(tee -a $${LOG_FILE}) 2>&1

echo "--- Starting VM Setup Script ---"

# --- Install Docker ---
echo "Installing Docker..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ubuntu

# --- Install New Relic Infrastructure Agent ---
echo "Installing New Relic Infrastructure Agent..."

# Enable New Relic's GPG key
curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -

# Add the infrastructure agent repository
printf "deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt focal main" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list

# Refresh the repositories
sudo apt-get update

# Install the package
sudo apt-get install -y newrelic-infra

# Create the config file for the agent
sudo cat <<EOF > /etc/newrelic-infra.yml
license_key: $${NEW_RELIC_LICENSE_KEY}
display_name: $${PROJECT_PREFIX}-vm
enable_process_metrics: true
custom_attributes:
  project: $${PROJECT_PREFIX}
  team: $${NEW_RELIC_TEAM_TAG}
  environment: $${NEW_RELIC_ENVIRONMENT_TAG}
EOF

# Enable Docker log collection
sudo cat <<EOF > /etc/newrelic-infra/logging.d/docker.yml
logs:
  - name: docker-log
    file: /var/lib/docker/containers/*/*.log
    attributes:
      logtype: docker
EOF

# Start the agent service
sudo systemctl enable newrelic-infra
sudo systemctl start newrelic-infra

echo "New Relic Infrastructure Agent configured and started."

# Setup the MSSQL OHI
echo "Installing New Relic MSSQL OHI..."

sudo apt-get install -y nri-mssql

sudo cat <<EOF > /etc/newrelic-infra/integrations.d/mssql-config.yml
integrations:
  - name: nri-mssql
    env:
      HOSTNAME: localhost
      PORT: 1433
      USERNAME: sa
      PASSWORD: $${SQL_PASSWORD}
      ENABLE_QUERY_MONITORING: true
      # Set to 1 to ensure we capture 'slow' queries for a demo
      QUERY_MONITORING_RESPONSE_TIME_THRESHOLD: 1
    interval: 15s
    labels:
      project: $${PROJECT_PREFIX}
      team: $${NEW_RELIC_TEAM_TAG}
      environment: $${NEW_RELIC_ENVIRONMENT_TAG}
    inventory_source: config/mssql
EOF

# Restart the agent
systemctl restart newrelic-infra

echo "New Relic MSSQL OHI configuration complete and Infrastructure agent restarted."

# --- Create Project Directory ---
echo "Creating project directory /opt/adventureworks..."
mkdir -p /opt/adventureworks
chown -R ubuntu:ubuntu /opt/adventureworks

# --- Copy Project Files ---
# The main terraform file will contain the actual content via templatefile function.

# Docker Compose file
cat <<EOF > /opt/adventureworks/docker-compose.yml
${docker_compose_file}
EOF

# --- Set up Environment for Docker Compose ---
echo "Creating .env file for Docker Compose..."
cat <<EOF > /opt/adventureworks/.env
SQL_PASSWORD=$${SQL_PASSWORD}
PROJECT_PREFIX=$${PROJECT_PREFIX}
NEW_RELIC_LICENSE_KEY=$${NEW_RELIC_LICENSE_KEY}
EOF

# --- Copy remaining project files to be built by Docker Compose ---
mkdir -p /opt/adventureworks/app/templates
mkdir -p /opt/adventureworks/mssql

cat <<EOF > /opt/adventureworks/app/Dockerfile
${app_dockerfile}
EOF
cat <<EOF > /opt/adventureworks/app/requirements.txt
${app_requirements_file}
EOF
cat <<EOF > /opt/adventureworks/app/app.py
${app_py_file}
EOF
cat <<EOF > /opt/adventureworks/app/locustfile.py
${app_locustfile_file}
EOF
cat <<EOF > /opt/adventureworks/app/templates/index.html
${app_index_html_file}
EOF
cat <<EOF > /opt/adventureworks/mssql/Dockerfile
${mssql_dockerfile}
EOF
cat <<EOF > /opt/adventureworks/mssql/setup_sql.sh
${mssql_setup_sql_file}
EOF
cat <<EOF > /opt/adventureworks/mssql/stored_procedures.sql
${mssql_stored_procedures_file}
EOF

# --- Build and Run Docker Containers ---
echo "Running Docker Compose..."
cd /opt/adventureworks
sudo docker compose -f docker-compose.yml up -d --build

echo "--- VM Setup Script Finished ---"
