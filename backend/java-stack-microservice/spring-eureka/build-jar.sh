ARTIFACT_ID="eureka"
# Change directory to the project folder
cd ${ARTIFACT_ID}
# Build the project to generate JAR file
if ./gradlew clean build; then
  echo "Build completed successfully."
else
  echo "Error: Build failed. Exiting."
  exit 1
fi