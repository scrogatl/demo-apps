#!/bin/bash
# This script runs inside the MSSQL container on startup
set -e

# --- Log Setup ---
# Direct logs to stdout, which can be viewed with 'docker logs'
echo "Starting SQL database setup for server: $(hostname)"

# Give SQL server a 20-second head start to initialize before we start polling
echo "Waiting 20 seconds for SQL Server process to initialize..."
sleep 20

# --- Wait for SQL Server to be ready ---
echo "Waiting for SQL Server to start..."
wait_time=600
for i in $(seq 1 $wait_time); do
    # Only redirect stdout to /dev/null, so we can see any errors from sqlcmd
    if /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -l 1 -Q "SELECT 1" > /dev/null 2>&1; then
        echo "SQL Server is up and ready for connections."
        break
    else
        echo "Still waiting for SQL Server... ($i/$wait_time)"
        sleep 1
    fi
done

# Check if the loop completed without a successful connection
if ! /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -l 1 -Q "SELECT 1" > /dev/null 2>&1; then
    echo "Error: SQL Server did not start within the timeout period."
    exit 1
fi

# --- Database Restore and Configuration ---
DB_NAME="AdventureWorks"
BAK_FILE_URL=""
BAK_FILE_PATH="/usr/src/app/AdventureWorks_custom.bak"

echo "Downloading AdventureWorks custom backup file from URL: $BAK_FILE_URL"
# Download the backup file to the container's local disk
curl -L -o "$BAK_FILE_PATH" "$BAK_FILE_URL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download the backup file."
    exit 1
fi
echo "Download complete."

echo "Restoring database from disk..."

# Restore the database from the local backup file
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d master -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = N'$BAK_FILE_PATH' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 5"
if [ $? -ne 0 ]; then
    echo "Error: Database restore failed."
    exit 1
fi
echo "Database restore successful."

# Clean up the backup file to save space
rm "$BAK_FILE_PATH"
echo "Backup file cleaned up."

echo "--- SQL database setup is complete. ---"
