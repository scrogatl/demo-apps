FROM mcr.microsoft.com/mssql/server:2022-latest

# Temporarily switch to root to install dependencies
USER root

# Install required packages using the modern, secure method for adding repository keys
RUN apt-get update && \
    apt-get install -y curl apt-transport-https gnupg && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

# Add the mssql-tools directory to the PATH for all users
ENV PATH="/opt/mssql-tools/bin:${PATH}"

WORKDIR /usr/src/app

# Copy the setup scripts and SQL files into the container
COPY setup_sql.sh .
COPY AdventureWorks_custom.bak .

# Grant execute permissions to the setup script
RUN chmod +x setup_sql.sh

# Grant ownership of the app directory to the mssql user
RUN chown -R mssql:mssql /usr/src/app

# Switch back to the default mssql user
USER mssql

# Execute our setup script in the background, and then start SQL Server
# in the foreground. The healthcheck in docker-compose will wait for the
# setup script to finish.
CMD /bin/bash ./setup_sql.sh & /opt/mssql/bin/sqlservr
