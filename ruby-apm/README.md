# Sample Distributed Ruby App with Docker, New Relic & Load Generation

This repository contains a sample distributed application built with Ruby (Rails and Sinatra), configured to run in Docker containers using Docker Compose. It includes built-in load generation and is instrumented with New Relic to demonstrate **Distributed Tracing**.

## Goal

The primary goal is to showcase how New Relic traces requests across multiple services. The load generator calls the `frontend` service (Rails), which in turn calls the `inventory_service` (Sinatra), which then calls the `user_service` (Sinatra). New Relic automatically links these calls into a single trace view.


## Prerequisites

* Docker: [Install Docker](https://docs.docker.com/get-docker/)
* Docker Compose: Usually included with Docker Desktop. [Install Docker Compose](https://docs.docker.com/compose/install/)
* A New Relic Account and License Key: [Sign up for New Relic](https://newrelic.com/signup)

## Architecture

```text
+-----------------+      +-----------------+      +-----------------+      +-----------------+
| Load Generator  | ---> |   frontend     | ---> |   inventory_service     | ---> |   user_service     |
| (Ruby Script)   |      |  (Rails App)    |      | (Sinatra App)   |      | (Sinatra App)   |
| Container       |      |  Container      |      |  Container      |      |  Container      |
| `loadgen`       |      |  `app`          |      |  `service_b`    |      |  `service_c`    |
|                 |      |  Port 3000      |      |  Port 4567      |      |  Port 4568      |
+-----------------+      +-----------------+      +-----------------+      +-----------------+
       |                      |                      |                      |
       +----------------------+----------------------+----------------------+---> New Relic Platform
                                    (APM Data & Distributed Traces)
```

* **Load Generator**: Sends requests to the `frontend` service's `/hello` endpoint.
* **Frontend (Rails)**: Receives the request, calls the `inventory_service`'s `/process` endpoint, and returns a combined response.
* **Inventory Service (Sinatra)**: Receives the request from the `frontend`, calls the `user_service`'s `/data` endpoint, and returns a combined response.
* **User Service (Sinatra)**: Receives the request from the `inventory_service`, performs minimal work, and returns data.
* **New Relic**: All three services (`frontend`, `inventory_service`, `user_service`) are instrumented with the New Relic Ruby agent. 
  * Distributed Tracing is enabled, allowing traces to flow across service boundaries.

### Project Structure

```text
├── .env.sample                  # sample .env for variables
├── Dockerfile.frontend          # Dockerfile for Frontend (Rails)
├── Dockerfile.inventory_service # Dockerfile for Inventory Service (Sinatra)
├── Dockerfile.loadgen           # Dockerfile for the load generator
├── Dockerfile.user_service      # Dockerfile for User Service (Sinatra)
├── docker-compose.yml           # Docker Compose configuration (UPDATED)
├── frontend/                    # Frontend service code (Rails)
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── app/
│   │   └── controllers/
│   │       └── application_controller.rb
│   │       └── welcome_controller.rb
│   ├── config/
│   │   └── environments/
│   │       └── production.rb
│   │   ├── application.rb
│   │   ├── boot.rb
│   │   ├── environment.rb
│   │   ├── puma.rb
│   │   ├── routes.rb
│   │   └── newrelic.yml
│   └── entrypoint.sh
│   └── Rakefile
│   └── config.ru
├── inventory_service/           # Inventory service code (Sinatra)
│   ├── Gemfile
│   ├── Gemfile.lock
│   └── inventory_service.rb
├── load_generator/              # Load generator code
│   └── load_generator.rb
└── user_service/                # User service code (Sinatra)
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── user_service.rb
```

## Setup

1. Clone the repository (or create the files):

```text
git clone <your-repo-url>
cd <repo-directory>
``` 
2. Configure variables:

* Edit the `.env` file
  * Copy and rename to `.env`
  * Update with your New Relic license key
  * Build a Rails secret and update with the base string

4. Build and Run the Application:

```text
docker compose build
docker compose up -d
```

* This will build images for all four containers and start them in detached mode.

## Usage

* **Access Frontend**: Open `http://localhost:3000`. You should see the welcome message.
  * Accessing `http://localhost:3000/hello` directly in your browser will show the full response including data from the downstream services.
* **View Logs**: `docker compose up` _(omitting the `-d` flag)_ streams logs from all containers (`frontend`, `inventory_service`, `user_service`, `loadgen`).
* **View New Relic Data**:
  * Log in to your New Relic account.
  * After a few minutes, data from the three applications (`Ruby Demo (Frontend)`, `Ruby Demo (InventorySvc)`, `Ruby Demo (UserSvc)`) should appear under APM & Services.
  * Navigate to "Distributed Tracing". You should see traces that span across all three services.
* **Stop the Application**: If running in console; press `Ctrl+C` in the terminal where `docker compose` up is running. Otherwise move to the next step.
* **Clean Up**:

```text
# Stops and removes containers/networks/volumes
docker compose down -v
```

### How Distributed Tracing Works Here
1. The `newrelic_rpm` gem is included in `frontend`, `inventory_service`, and `user_service`.
2. `NEW_RELIC_DISTRIBUTED_TRACING_ENABLED=true` is set by default on all APM agents.
3. When `frontend` makes an HTTP request to `inventory_service` using `Net::HTTP`, the New Relic agent automatically injects W3C Trace Context headers into the outgoing request.
4. When `inventory_service` receives the request, its New Relic agent recognizes these headers and continues the trace initiated by `frontend`.
5. The same process happens when `inventory_service` calls `user_service`.