# Use OpenJDK base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy Eureka Server JAR file to the image
COPY build/libs/eureka-*-SNAPSHOT.jar /app/eureka.jar

# Expose default Eureka port
EXPOSE 8761

# Run the Eureka Server
ENTRYPOINT ["java", "-jar", "/app/eureka.jar"]
