FROM openjdk:17-jdk-slim

WORKDIR /app

# COPY LOCAL JAR FILE
COPY target/spring-cloud-config.jar /app/spring-cloud-config.jar

EXPOSE 8888

ENTRYPOINT ["java", "-jar", "/app/spring-cloud-config.jar"]
