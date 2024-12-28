# Use OpenJDK as the base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy the JAR file of the auth service
COPY target/auth-service.jar /app/auth-service.jar

# Expose the default application port (customize as needed)
EXPOSE 8084

# Run the auth service
ENTRYPOINT ["java", "-jar", "/app/auth-service.jar"]
