# Use OpenJDK as the base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy the JAR file of the payment service
COPY target/payment-service.jar /app/payment-service.jar

# Expose the default application port (customize as needed)
EXPOSE 8082

# Run the payment service
ENTRYPOINT ["java", "-jar", "/app/payment-service.jar"]
