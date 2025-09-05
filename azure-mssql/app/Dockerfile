# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set the working directory in the container
WORKDIR /app

# Temporarily switch to root to install system dependencies
USER root

# Install system packages required for the ODBC driver and other dependencies
RUN apt-get update && \
    apt-get install -y curl gnupg unixodbc-dev

# Add Microsoft's official repository for the ODBC driver using the modern, secure method
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list

# Update package lists again and install the ODBC driver
RUN apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17

# Copy the requirements file and install Python packages as root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create a non-root user and switch to it
RUN addgroup --system app && adduser --system --group app
USER app

# Copy the rest of the application code into the container
COPY . .

# Expose ports for Flask and Locust
EXPOSE 5000
EXPOSE 8089

# Run app.py with NR APM when the container launches.
CMD ["newrelic-admin", "run-program", "gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app:app"]
