#!/bin/bash
# This script runs inside the MSSQL container on startup
set -e

echo "=== Starting SQL database setup for server: $(hostname) ==="

# Wait for the SQL Server to be fully initialized by monitoring for tempdb readiness
echo "=== Waiting for SQL Server to finish initialization... ==="
MAX_TRIES=60
TRIES=0
# The until loop continues until the sqlcmd command successfully finds 'tempdb'.
# -W removes trailing whitespace and -h-1 removes headers for clean output.
# grep -q is "quiet mode", it just returns a success/failure exit code.
until /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -W -h-1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name = N'tempdb'" | grep -q "tempdb"
do
    TRIES=$((TRIES + 1))
    if [ "$TRIES" -ge "$MAX_TRIES" ]; then
        echo "=== Error: SQL Server did not become available within "$MAX_TRIES" attempts. ==="
        exit 1
    fi
    echo "=== SQL Server is unavailable - sleeping for 5s (Attempt ${TRIES}/${MAX_TRIES}) ==="
    sleep 5
done

echo "=== SQL Server is ready. Starting the AdventureWorks restore... ==="
# --- Database Restore and Configuration ---
# Download the backup file to the container's local disk
echo "=== Downloading database backup file... ==="
curl -L "https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2022.bak" > "/tmp/AdventureWorks2022.bak"
if [ $? -ne 0 ]; then
    echo "=== Error: Failed to download the backup file. ==="
    exit 1
fi
echo "=== Download complete. ==="

# Restore the database from the local backup file
echo "=== Restoring database from disk... ==="
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d master -Q "RESTORE DATABASE [AdventureWorks] FROM DISK = N'/tmp/AdventureWorks2022.bak' WITH FILE = 1, NOUNLOAD, REPLACE, STATS = 5, MOVE 'AdventureWorks2022' TO '/var/opt/mssql/data/AdventureWorks2022.mdf', MOVE 'AdventureWorks2022_log' TO '/var/opt/mssql/data/AdventureWorks2022_log.ldf'"

if [ $? -ne 0 ]; then
    echo "=== Error: Database restore failed. ==="
    exit 1
fi
echo "=== Database restore successful. ==="

# Run the stored procedure script
echo "=== Running stored procedure setup script... ==="
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -d AdventureWorks -i ./stored_procedures.sql
if [ $? -ne 0 ]; then
    echo "=== Error: Stored procedure script failed. ==="
    exit 1
fi
echo "=== Stored procedures created successfully. ==="

# Clean up the backup file to save space
rm /tmp/AdventureWorks2022.bak
echo "=== Backup file cleaned up. ==="

echo "--- === SQL database setup is complete. SQL Server is running. ===  ---"

# 'wait' tells the script to pause here and wait for the SQL
# Server process to exit. This keeps the container alive.
wait $SQL_SERVER_PID
