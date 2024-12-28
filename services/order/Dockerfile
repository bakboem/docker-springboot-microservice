# Use OpenJDK as the base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy the JAR file of the order service
COPY target/order-service.jar /app/order-service.jar

# Expose the default application port (customize as needed)
EXPOSE 8081

# Run the order service
ENTRYPOINT ["java", "-jar", "/app/order-service.jar"]
