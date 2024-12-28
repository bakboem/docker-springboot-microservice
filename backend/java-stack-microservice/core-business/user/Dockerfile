# Use OpenJDK as the base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy the JAR file of the user service
COPY target/user-service.jar /app/user-service.jar

# Expose the default application port (customize as needed)
EXPOSE 8083

# Run the user service
ENTRYPOINT ["java", "-jar", "/app/user-service.jar"]
