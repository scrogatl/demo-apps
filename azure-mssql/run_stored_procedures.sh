#!/bin/bash
# This script is designed to be run from the Ubuntu host *after* the Docker containers are running.
# It executes the stored_procedures.sql script inside the running MSSQL container.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Script Usage Check ---
if [ -z "$MSSQL_SA_PASSWORD" ]; then
  # 1. Print an error message to standard error (>&2)
  echo "Error: The MSSQL_SA_PASSWORD environment variable is not set. Please set it and try again." >&2
  # 2. Exit the script with a non-zero status code to indicate failure
  exit 1
fi

# If the script reaches this point, the variable is set.
echo "=== Success! MSSQL_SA_PASSWORD is set. ==="
echo "Continuing with the rest of the script..."
echo "Attempting to run stored procedures in container: adventureworks_db..."

# --- Execute the SQL Script ---
# Use 'docker exec' to run the sqlcmd utility inside the container.
# The '-b' flag tells sqlcmd to exit with an error code if any SQL statement fails.
sudo docker exec adventureworks_db /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "$MSSQL_SA_PASSWORD" \
    -d "AdventureWorks" \
    -i /usr/src/app/stored_procedures.sql \
    -b

# Check the exit code of the docker exec command
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute stored procedures."
    exit 1
fi

echo "Stored procedures script executed successfully."
echo ""
echo "--- Verifying Created Stored Procedures ---"

# --- Verification Step ---
# Query the sys.procedures view to list all user-created stored procedures.
# The output will be displayed on the host's stdout.
sudo docker exec adventureworks_db /opt/mssql-tools/bin/sqlcmd \
    -S localhost \
    -U sa \
    -P "$MSSQL_SA_PASSWORD" \
    -d "AdventureWorks" \
    -Q "SELECT name FROM sys.procedures WHERE is_ms_shipped = 0 ORDER BY name;"

echo "--- Verification Complete ---"
