# Use OpenJDK as the base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy the JAR file of the producer application
COPY target/msg-producer.jar /app/msg-producer.jar

# Expose the default application port (customize as needed)
EXPOSE 8080

# Run the producer application
ENTRYPOINT ["java", "-jar", "/app/msg-producer.jar"]