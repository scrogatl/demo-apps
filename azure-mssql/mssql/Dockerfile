FROM mcr.microsoft.com/mssql/server:2022-latest

# Switch to root to install dependencies.
USER root

# Set an ARG for non-interactive installs, a Docker best practice.
ARG DEBIAN_FRONTEND=noninteractive
# Set the EULA environment variable so it's available for the mssql-tools install.
ENV ACCEPT_EULA=Y

# This single RUN command installs all dependencies in one layer for efficiency.
# It installs base dependencies, gosu for privilege-dropping, adds the Microsoft repo,
# installs mssql-tools, and cleans up to reduce image size.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl gnupg gpg dirmngr && \
    gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" && \
    curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64.asc" && \
    gpg --verify /usr/local/bin/gosu.asc && \
    rm /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends mssql-tools unixodbc-dev && \
    apt-get purge -y --auto-remove gpg dirmngr && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Add mssql-tools to the PATH for all users.
ENV PATH="/opt/mssql-tools/bin:${PATH}"

# Copy all necessary scripts and files.
WORKDIR /usr/src/app
COPY stored_procedures.sql .
COPY setup_sql.sh .
COPY entrypoint.sh /usr/local/bin/

# Make both scripts executable.
RUN chmod +x /usr/src/app/setup_sql.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
