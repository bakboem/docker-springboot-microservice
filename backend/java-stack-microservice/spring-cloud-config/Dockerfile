# Use OpenJDK base image
FROM openjdk:17-jdk-slim

# Set working directory
WORKDIR /app

# Copy Eureka Server JAR file to the image
COPY config-server/build/libs/config-server-*-SNAPSHOT.jar /app/config-server.jar

# 可选：复制默认的 application.yml（仅作备份用途）
COPY application.docker.yml /app/config/application.yml

RUN apt-get update && apt-get install -y curl
# Expose default Eureka port
EXPOSE 8888 
# Run the Eureka Server
ENTRYPOINT ["java", "-jar", "/app/config-server.jar","--spring.config.location=file:/app/config/"]
