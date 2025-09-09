#!/bin/bash
# Exit immediately if a command exits with a non-zero status.
set -e

# Fix permissions on the volume mount.
# This MUST happen first, as root, before the sqlservr process starts.
# Otherwise, sqlservr cannot write its log files and will fail.
echo "=== Entrypoint: Setting ownership of /var/opt/mssql to mssql user... ==="
chown -R mssql:mssql /var/opt/mssql

# Run the setup logic in a background function.
# This allows the main SQL Server process to start up in parallel.
run_setup() {
    echo "=== Entrypoint: Waiting for SQL Server to be ready... ==="

    # Wait for SQL Server to be ready by checking the availability of tempdb
    until /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -h -1 -W -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name = N'tempdb'" &>/dev/null; do
        >&2 echo "SQL Server is unavailable - sleeping"
        sleep 1
    done

    echo "=== Entrypoint: SQL Server is ready. Executing SQL setup script to restore AdventureWorks DB. ==="
    /usr/src/app/setup_sql.sh
    echo "=== Entrypoint: Setup script finished. ==="
}

# Run the setup function in the background
run_setup &

# Start SQL Server in the foreground
# The 'exec' command replaces the current shell process with the sqlservr process.
# This makes sqlservr the main process (PID 1) of the container.
echo "=== Entrypoint: Starting SQL Server as user 'mssql'... ==="
exec gosu mssql /opt/mssql/bin/sqlservr
