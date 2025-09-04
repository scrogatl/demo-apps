#!/bin/bash
# This script runs inside the MSSQL container on startup
set -e

# --- Log Setup ---
# Direct logs to stdout, which can be viewed with 'docker logs'
echo "Starting SQL database setup for server: $(hostname)"

# --- Wait for SQL Server to be ready ---
echo "Waiting for SQL Server to start..."
wait_time=90
for i in $(seq 1 $wait_time); do
    # Try to connect. The -l 1 sets a 1-second login timeout.
    # The -b flag ensures the script will exit on error.
    if sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -l 1 -Q "SELECT 1" &>/dev/null; then
        echo "SQL Server is up and ready for connections."
        break
    else
        echo "Still waiting for SQL Server... ($i/$wait_time)"
        sleep 1
    fi
done

# Check if the loop completed without a successful connection
if ! sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -l 1 -Q "SELECT 1" &>/dev/null; then
    echo "Error: SQL Server did not start within the timeout period."
    exit 1
fi

# --- Database Restore and Configuration ---
DB_NAME="AdventureWorks"
BAK_FILE_PATH="/usr/src/app/AdventureWorks2022.bak"
DOWNLOAD_URL="https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak"

# Check if the database already exists
if sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d master -Q "IF DB_ID('$DB_NAME') IS NOT NULL SELECT 1 ELSE SELECT 0" | grep -q "1"; then
    echo "Database '$DB_NAME' already exists. Skipping restore and setup."
else
    echo "Database '$DB_NAME' not found. Starting restore process..."

    echo "Downloading AdventureWorks backup file..."
    # Download the backup file to the container's local disk
    curl -L -o "$BAK_FILE_PATH" "$DOWNLOAD_URL"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download the backup file."
        exit 1
    fi
    echo "Download complete."

    echo "Restoring database from disk..."
    # Restore the database from the local backup file
    sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d master -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = N'$BAK_FILE_PATH' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 5"
    if [ $? -ne 0 ]; then
        echo "Error: Database restore failed."
        exit 1
    fi
    echo "Database restore successful."

    echo "Running stored procedure setup script..."
    # Run the script to create stored procedures and other test scenarios
    sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d "$DB_NAME" -i /usr/src/app/stored_procedures.sql -b
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create stored procedures."
        exit 1
    fi
    echo "Stored procedures created successfully."

    # Clean up the backup file to save space
    rm "$BAK_FILE_PATH"
    echo "Backup file cleaned up."
fi

echo "--- SQL database setup is complete. ---"
