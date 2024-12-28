# Use OpenJDK base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy Spring Cloud Gateway JAR file
COPY target/spring-cloud-gateway.jar /app/spring-cloud-gateway.jar

# Expose default Gateway port (customize if needed)
EXPOSE 8080

# Run the Spring Cloud Gateway
ENTRYPOINT ["java", "-jar", "/app/spring-cloud-gateway.jar"]
