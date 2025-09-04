FROM mcr.microsoft.com/mssql/server:2022-latest

# Temporarily switch to root to install dependencies
USER root

# Install required packages and the MSSQL command-line tools
# Added 'gnupg' to the install list as it's a required dependency.
RUN apt-get update && \
    apt-get install -y curl apt-transport-https gnupg && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

# Add the mssql-tools directory to the PATH for all users
ENV PATH="/opt/mssql-tools/bin:${PATH}"

WORKDIR /usr/src/app

# Copy the setup scripts and SQL files into the container
COPY setup_sql.sh .
COPY stored_procedures.sql .

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
