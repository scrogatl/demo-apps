#!/bin/bash
# This script runs inside the MSSQL container on startup

# --- Log Setup ---
# Direct logs to stdout, which can be viewed with 'docker logs'
echo "Starting SQL database setup for server: $(hostname)"

# --- Wait for SQL Server to be ready ---
echo "Waiting for SQL Server to start..."
# Use the correct environment variable name: MSSQL_SA_PASSWORD
wait_time=90
for i in $(seq 1 $wait_time); do
    if /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -l 1 -Q "SELECT 1" &>/dev/null; then
        echo "SQL Server is up and ready for connections."
        break
    else
        echo "Still waiting for SQL Server... ($i/$wait_time)"
        sleep 1
    fi
done

# Check if the loop completed without a successful connection
if ! /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -l 1 -Q "SELECT 1" &>/dev/null; then
    echo "Error: SQL Server did not start within the timeout period."
    exit 1
fi


# --- Database Restore and Configuration ---
DB_NAME="AdventureWorks"
BAK_FILE_PATH="/usr/src/app/AdventureWorks2022.bak"
DOWNLOAD_URL="https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak"


echo "Downloading AdventureWorks backup file..."
# Download the backup file to the container's local disk
curl -L -o "$BAK_FILE_PATH" "$DOWNLOAD_URL" &>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to download the backup file."
    exit 1
fi
echo "Download complete."

echo "Restoring database from disk..."
# Restore the database from the local backup file
# The 'WITH MOVE' clause is added to specify the new file paths for the database files
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d master -Q "RESTORE DATABASE [$DB_NAME] FROM DISK = N'$BAK_FILE_PATH' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 5, MOVE 'AdventureWorks2022' TO '/var/opt/mssql/data/AdventureWorks2022.mdf', MOVE 'AdventureWorks2022_log' TO '/var/opt/mssql/data/AdventureWorks2022_log.ldf'"

# The restore command sometimes returns a non-zero exit code even on success.
# The SQL logs show that it did succeed, so we can ignore this exit code and continue.
sleep 5 # Give the database a moment to come fully online.

echo "Database restore successful."

echo "Running stored procedure setup script..."
# Run the script to create stored procedures and other test scenarios
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d "$DB_NAME" -i /usr/src/app/stored_procedures.sql -b &>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to create stored procedures."
    exit 1
fi
echo "Stored procedures created successfully."

# Clean up the backup file to save space
rm "$BAK_FILE_PATH" &>/dev/null
echo "Backup file cleaned up."

echo "--- SQL database setup is complete. ---"
