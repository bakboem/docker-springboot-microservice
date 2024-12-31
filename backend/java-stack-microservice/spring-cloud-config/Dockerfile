# Use OpenJDK base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy Eureka Server JAR file to the image
COPY config-server/build/libs/config-server-*-SNAPSHOT.jar /app/config-server.jar

# Expose default Eureka port
EXPOSE 8888 
EXPOSE 8761

# Run the Eureka Server
ENTRYPOINT ["java", "-jar", "/app/eureka.jar"]
