# Use OpenJDK base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy Eureka Server JAR file to the image
COPY auth-resource-server/build/libs/auth-resource-server-*-SNAPSHOT.jar /app/auth-resource-server.jar

# 可选：复制默认的 application.yml（仅作备份用途）
COPY application.docker.yml /app/config/application.yml

RUN apt-get update && apt-get install -y curl
# Expose default Eureka port
EXPOSE 8084
# Run the Eureka Server
ENTRYPOINT ["java", "-jar", "/app/auth-resource-server.jar","--spring.config.location=file:/app/config/"]
