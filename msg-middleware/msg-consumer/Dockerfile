# Use OpenJDK as the base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy the JAR file of the consumer application
COPY target/msg-consumer.jar /app/msg-consumer.jar

# Expose the default application port (if applicable, otherwise optional)
EXPOSE 8081

# Run the consumer application
ENTRYPOINT ["java", "-jar", "/app/msg-consumer.jar"]
