#!/bin/bash



# Set variables for project generation
GROUP_ID="com.codera"
ARTIFACT_ID="eureka"
NAME="eureka"
DESCRIPTION="Eureka For Service Discovery System"
PACKAGE_NAME="com.codera.eureka"
BOOT_VERSION="3.4.1"

# Check if the project folder already exists
if [ -d "./${ARTIFACT_ID}" ]; then
  echo "Directory '${ARTIFACT_ID}' already exists. Skipping project generation."
  exit 0
fi


# Download and extract Spring Boot project
curl "https://start.spring.io/starter.tgz" \
  -d type=gradle-project \
  -d language=java \
  -d bootVersion=${BOOT_VERSION} \
  -d groupId=${GROUP_ID} \
  -d artifactId=${ARTIFACT_ID} \
  -d name=${NAME} \
  -d description="${DESCRIPTION}" \
  -d packageName=${PACKAGE_NAME} \
  --output ${ARTIFACT_ID}.tgz

# Extract the project
tar -xzf ${ARTIFACT_ID}.tgz

# Change directory to the project folder
cd ${ARTIFACT_ID}

# Build the project to generate JAR file
./gradlew clean build
