# ECM Project Overview

## Project Structure

### Backend

1. **java-stack-microservice**: A set of microservices implemented in Java using Spring Boot.

   - **core-business**: Handles the main business logic.
   - **msg-consumer**: Consumes messages from Kafka topics.
   - **msg-producer**: Produces messages to Kafka topics.
   - **spring-cloud-config**: Centralized configuration management for microservices.
   - **spring-cloud-gateway**: API gateway for routing requests to microservices.
   - **spring-eureka**: Service discovery and registration.
   - **spring-security**: Security module for authentication and authorization.

2. **nocode-standalone-instance**: Contains independent services for various infrastructure components.

   - **db**:
     - **main-db**: Main database.
     - **redis**: Caching and message brokering service.
     - **replication-db**: Replicated database instance for read scaling.
   - **kafka**: Message broker using Kafka.
   - **log**: Centralized logging service.
   - **monitoring**:
     - **grafana**: Visualization and monitoring.
     - **influx**: Time-series database for metrics.
     - **prometheus**: Metrics collection and alerting.

### Frontend

- Placeholder for frontend-related code and components.

### Infra

- Contains infrastructure scripts and configurations for deployment.

## Key Features

### Dockerized Environment

All services are containerized using Docker, making it easy to manage, scale, and deploy.

### Environment Proxies with Ngrok

- Added **ngrok** to expose the local environment to the external network.
- **ngrok** is configured to map local port 80 to a publicly accessible URL for testing and debugging external integrations.
- Scripts automate the detection of port mapping and update the `KAFKA_CFG_ADVERTISED_LISTENERS` dynamically with the ngrok public URL.

### Deployment and Automation

- Automated deployment scripts for each service.
- `docker-compose` files for development and production environments:
  - **docker-compose-dev.yml**: For local development.
  - **docker-compose-prod.yml**: For production setups.
  - **docker-compose.override.yml**: Custom overrides for specific configurations.

## Running the Project

### Prerequisites

- Docker and Docker Compose installed.
- Ngrok installed locally.
- Required ports (e.g., 80, 9092) available on the host machine.

### Steps

1. Clone the repository.
2. Run the infrastructure setup:
   ```bash
   ./start.sh
   ```
3. Ensure ngrok is properly configured to map local ports. The script `extract-ngrok-ip.sh` ensures dynamic updates to the environment variables for Kafka:
   ```bash
   ./extract-ngrok-ip.sh
   ```
4. Use Docker Compose to bring up the services:
   ```bash
   docker-compose -f docker-compose-dev.yml up
   ```

### Health Checks

Each service is configured with health checks to ensure proper operation. For example:

- Kafka: Verifies port 9092 availability using `netcat`.
- Other services: Periodic health probes to ensure responsiveness.

## Key Notes

- Kafka’s `advertised.listeners` is dynamically updated to use the ngrok public URL to allow external access.
- The project is designed with scalability in mind. For example:
  - Redis and databases can scale horizontally.
  - Kafka and log services support distributed setups.
- Monitoring tools (Grafana and Prometheus) are pre-configured for visualizing service metrics.

## Scripts

1. **start.sh**: Starts all services.
2. **stop.sh**: Stops all services.
3. **extract-ngrok-ip.sh**: Dynamically updates environment variables for ngrok.
4. **build-image.sh**: Builds Docker images for services.

## Future Plans

- Implement business logic for microservices in the `java-stack-microservice` folder.
- Extend monitoring capabilities with custom dashboards.
- Optimize database queries and caching for high performance.
- Integrate the frontend with the backend services.

## Contact

For further assistance, reach out to the project maintainer.
