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

# 4. Create the systemd service for the NORMAL load
cat << 'EOF' > /etc/systemd/system/normal-load.service
[Unit]
Description=Run a normal, varying load on CPU and Memory
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do \
  CPU_LOAD=$$(shuf -i 10-18 -n 1); \
  MEM_LOAD=$$(shuf -i 330-420 -n 1); \
  echo "Starting normal-load stress-ng with CPU_LOAD: $${CPU_LOAD} and MEM_LOAD: $${MEM_LOAD}M"; \
  /usr/bin/stress-ng --cpu 1 --cpu-load $${CPU_LOAD} --vm 1 --vm-bytes $${MEM_LOAD}M -t 120s || echo "normal-load stress-ng FAILED with exit code $$?"; \
  sleep $$(shuf -i 5-30 -n 1); \
done'
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

# 5. Create the SPIKE script
# The timer handles all scheduling and randomness.
cat << 'EOF' > /usr/local/bin/run_memory_spike.sh
#!/bin/bash

echo "Starting memory spike..."

# Get random duration (7-12 minutes)
DURATION=$(shuf -i 420-720 -n 1)

echo "Starting memory spike stress-ng with DURATION: ${DURATION}s"

# Run stress-ng with failure catch
# --vm-hang is set to $DURATION to hold the memory for the entire spike
/usr/bin/stress-ng --vm 1 --vm-bytes 90% -t ${DURATION}s --vm-hang ${DURATION} || echo "memory-spike stress-ng FAILED with exit code $?"

echo "Memory spike complete."
EOF

# 6. Make the spike script executable
chmod +x /usr/local/bin/run_memory_spike.sh

# 7. Create the SPIKE .service file
cat << 'EOF' > /etc/systemd/system/memory-spike.service
[Unit]
Description=Run a memory spike
[Service]
Type=oneshot
ExecStart=/usr/local/bin/run_memory_spike.sh
EOF

# 8. Create the SPIKE .timer file
cat << 'EOF' > /etc/systemd/system/memory-spike.timer
[Unit]
Description=Run memory-spike.service 4-8 hours after last run
[Timer]
# Wait 4 hours after the service was last active
OnUnitActiveSec=4h
# Add a random delay of 0-4 hours (14400 seconds)
RandomizedDelaySec=14400
Persistent=true
[Install]
WantedBy=timers.target
EOF

# 9. Reload, enable, and start all services
systemctl daemon-reload

# Start the normal load
systemctl enable normal-load.service
systemctl start normal-load.service

# Start the spike timer
systemctl enable memory-spike.timer
systemctl start memory-spike.timer
