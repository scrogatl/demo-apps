#!/bin/bash -xe

# 1. Install Updates & Prereqs
yum update -y
amazon-linux-extras install epel -y
yum install stress-ng -y

# 2. Install New Relic Agent
# The templatefile function in main.tf will replace these variables.
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY=${nr_api_key} NEW_RELIC_ACCOUNT_ID=${nr_account_id} /usr/local/bin/newrelic install -n infrastructure-agent-installer,logs-integration -y --tag 'team:Demo Engineering','app:outlier_detection'

# 3. Enable the New Relic agent
systemctl enable newrelic-infra --now

# 4. Create the systemd service for the normal load
cat << 'EOF' > /etc/systemd/system/normal-load.service
[Unit]
Description=Run a normal, varying load on CPU and Memory
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do \
  CPU_LOAD=$$(shuf -i 10-18 -n 1); \
  MEM_LOAD=$$(shuf -i 330-420 -n 1); \
  /usr/bin/stress-ng --cpu 1 --cpu-load $${CPU_LOAD} --vm 1 --vm-bytes $${MEM_LOAD}M -t 120s; \
  sleep $$(shuf -i 5-30 -n 1); \
done'
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

# 5. Start the normal load service
systemctl daemon-reload
systemctl enable normal-load.service
systemctl start normal-load.service
