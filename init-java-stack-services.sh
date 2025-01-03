#!/bin/bash
set -e 
trap stop_all EXIT
# 设置主路径
JAVA_STACK_PATH="./backend/java-stack-microservice"
EUREKA_DIR="$JAVA_STACK_PATH/spring-eureka"
EUREKA_ARTIFACT_DIR="$EUREKA_DIR/eureka"
EUREKA_PID=""

CONFIG_DIR="$JAVA_STACK_PATH/spring-cloud-config"
CONFIG_ARTIFACT_DIR="$CONFIG_DIR/config-server"
CONFIG_PID=""


# Function to start the local Eureka server
start_local_eureka() {
  echo "Starting local Eureka server..."
  
  # 使用 ls 获取匹配的 JAR 文件
  JAR_FILE=$(ls "$EUREKA_ARTIFACT_DIR/build/libs/"eureka-*-SNAPSHOT.jar 2>/dev/null | head -n 1)

  if [ -z "$JAR_FILE" ]; then
    echo "Error: Unable to find the JAR file in $EUREKA_ARTIFACT_DIR/build/libs/"
    exit 1
  fi

  java -jar "$JAR_FILE" &
  EUREKA_PID=$!
  echo "Eureka server started with PID $EUREKA_PID"
  sleep 10  # Wait for Eureka to stabilize
}

# Function to stop the local Eureka server
stop_local_eureka() {
  if [ -n "$EUREKA_PID" ]; then
    echo "Stopping local Eureka server with PID $EUREKA_PID..."
    kill "$EUREKA_PID"
    wait "$EUREKA_PID" 2>/dev/null || echo "Eureka server stopped."
  else
    echo "No Eureka server process found to stop."
  fi
}

stop_all() {
  stop_local_config
  stop_local_eureka
 
  # Check if a Kafka container ID is passed as an argument
  local kafka_container_id="$1"

  if [ -z "$kafka_container_id" ]; then
    # If no ID is passed, try to find the container by name
    echo "No Kafka container ID provided. Searching by container name..."
    kafka_container_id=$(docker ps -q -f name=temp-kafka-container)
    if [ -z "$kafka_container_id" ]; then
      echo "No running Kafka container found with the name 'temp-kafka-container'."
      return 0
    fi
  fi

  # Stop and remove the Kafka container
  echo "Stopping and removing Kafka container with ID: $kafka_container_id"
  docker rm -f "$kafka_container_id"
  if [ $? -eq 0 ]; then
    echo "Kafka container removed successfully."
  else
    echo "Failed to remove Kafka container."
    exit 1
  fi
}


# Function to start the local Eureka server
start_local_config() {
  echo "Starting local Eureka server..."
  
  # 使用 ls 获取匹配的 JAR 文件
  JAR_FILE=$(ls "$CONFIG_ARTIFACT_DIR/build/libs/"config-server-*-SNAPSHOT.jar 2>/dev/null | head -n 1)

  if [ -z "$JAR_FILE" ]; then
    echo "Error: Unable to find the JAR file in $CONFIG_ARTIFACT_DIR/build/libs/"
    exit 1
  fi

  java -jar "$JAR_FILE" &
  CONFIG_PID=$!
  echo "Eureka server started with PID $CONFIG_PID"
  sleep 10  # Wait for Eureka to stabilize
}

# Function to stop the local Eureka server
stop_local_config() {
  if [ -n "$CONFIG_PID" ]; then
    echo "Stopping local Eureka server with PID $CONFIG_PID..."
    kill "$CONFIG_PID"
    wait "$CONFIG_PID" 2>/dev/null || echo "Eureka server stopped."
  else
    echo "No Config server process found to stop."
  fi
}

process_config_files() {
  local EUREKA_SERVER_NAME="$1"
  local KAFKA_SERVER_NAME="$2"
  local subdir="$3"
  local ARTIFACT_ID="$4"
  local artifact_dir="$subdir/$ARTIFACT_ID"
  local config_dir="$artifact_dir/src/main/resources"
  local yaml_source="$subdir/application.yml"
  local properties_file="$config_dir/application.properties"
  local eurekaClassFile="$artifact_dir/src/main/java/com/codera/eureka/EurekaServerApplication.java"
  local LOCAL_HOST="localhost"
  # 处理 application.docker.yml
  local docker_config="$subdir/application.docker.yml"
  mkdir -p "$config_dir"
  
  # 定义变量替换规则
  replacements_docker=(
    "\$localhost-or-eureka-docker-server-name=$EUREKA_SERVER_NAME"
    "\$localhost-or-kafka-docker-server-name=$KAFKA_SERVER_NAME"
  )
  replacements_local=(
    "\$localhost-or-eureka-docker-server-name=$LOCAL_HOST" 
    "\$localhost-or-kafka-docker-server-name=$LOCAL_HOST"
  )

  # 通用的变量替换函数
  replace_variables() {
    local file="$1"
    local vars=("${!2}") # 接收数组作为参数

    for kv in "${vars[@]}"; do
      key="${kv%%=*}"  # 提取键
      value="${kv#*=}" # 提取值
      if grep -q "$key" "$file"; then
        echo "Replacing $key with $value in $file"
        sed -i.bak "s|$key|$value|g" "$file"
        rm "$file.bak"
      fi
    done
  }

  echo "Processing configuration files in $config_dir"

  if [ -f "$yaml_source" ]; then
    echo "Creating Docker-specific configuration: $docker_config"
    cp "$yaml_source" "$docker_config"
    replace_variables "$docker_config" replacements_docker[@]
  else
    echo "Warning: $yaml_source does not exist. Skipping Docker configuration."
  fi

  # 处理 config_dir/application.yml
  local local_config="$config_dir/application.yml"
  if [ -f "$yaml_source" ]; then
    echo "Creating local configuration: $local_config"
    cp "$yaml_source" "$local_config"
    replace_variables "$local_config" replacements_local[@]
  else
    echo "Warning: $yaml_source does not exist. Skipping local configuration."
  fi

  # 删除 application.properties（如果存在）
  if [ -f "$properties_file" ]; then
    echo "Deleting $properties_file"
    rm -f "$properties_file"
  fi

  # 检查并处理 EurekaServerApplication.java 文件
  if [ -f "$eurekaClassFile" ]; then
    echo "Checking $eurekaClassFile for @EnableEurekaServer..."
    
    if ! grep -q "@EnableEurekaServer" "$eurekaClassFile"; then
      echo "@EnableEurekaServer not found. Adding annotation and import..."
      
      # 添加 import
      if ! grep -q "import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;" "$eurekaClassFile"; then
        sed -i.bak '1 a\
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;' "$eurekaClassFile"
      fi

      # 添加 @EnableEurekaServer
      sed -i.bak '/@SpringBootApplication/a\
@EnableEurekaServer\
' "$eurekaClassFile"
      rm "$eurekaClassFile.bak"
      echo "@EnableEurekaServer added."
    else
      echo "@EnableEurekaServer already present."
    fi
  else
    echo "EurekaServerApplication.java not found in $artifact_dir"
  fi
}


# Function to process a single project directory
process_directory() {
  local subdir="$1"

  # Check for build-config.yml
  local config_file="$subdir/build-config.yml"
  if [ ! -f "$config_file" ]; then
    echo "Skipping $subdir: Missing build-config.yml"
    return
  fi

  # Extract configuration parameters
  # 使用 yq 提取参数
  local GROUP_ID=$(yq '.GROUP_ID' "$config_file")
  local ARTIFACT_ID=$(yq '.ARTIFACT_ID' "$config_file")
  local NAME=$(yq '.NAME' "$config_file")
  local DESCRIPTION=$(yq '.DESCRIPTION' "$config_file")
  local BOOT_VERSION=$(yq '.BOOT_VERSION' "$config_file")
  local EUREKA_SERVER_NAME=$(yq '.EUREKA_SERVER_NAME' "$config_file")
  local KAFKA_SERVER_NAME=$(yq '.KAFKA_SERVER_NAME' "$config_file")
  local DEPENDENCIES=$(yq -r '.DEPENDENCIES[]' "$config_file" | paste -sd "," -)

  echo "Processing $ARTIFACT_ID in $subdir"

  local artifact_dir="$subdir/$ARTIFACT_ID"

  # Check if project directory exists
  if [ -d "$artifact_dir" ]; then
    echo "Directory '$ARTIFACT_ID' already exists in $subdir."
    process_config_files "$EUREKA_SERVER_NAME" "$KAFKA_SERVER_NAME" "$subdir" "$ARTIFACT_ID"

    # Build the project
    cd "$artifact_dir" || { echo "Failed to change directory to $artifact_dir"; return; }
    chmod +x ./gradlew
    if ! ./gradlew clean build --no-build-cache; then
      echo "Error: Build failed for $ARTIFACT_ID."
      cd - > /dev/null
      return
    fi
    cd - > /dev/null
    return
  fi

  # Generate new project
  echo "Generating Spring Boot project: $ARTIFACT_ID"
  curl "https://start.spring.io/starter.tgz" \
    -d type=gradle-project \
    -d language=java \
    -d bootVersion=$BOOT_VERSION \
    -d groupId=$GROUP_ID \
    -d artifactId=$ARTIFACT_ID \
    -d name=$NAME \
    -d description="$DESCRIPTION" \
    -d dependencies=$DEPENDENCIES \
    -d packageName=$PACKAGE_NAME \
    --output "$subdir/$ARTIFACT_ID.tgz"

  if ! tar -tzf "$subdir/$ARTIFACT_ID.tgz" > /dev/null 2>&1; then
    echo "Error: Invalid archive format for $ARTIFACT_ID. Skipping..."
    return
  fi

  mkdir -p "$artifact_dir"
  tar -xzf "$subdir/$ARTIFACT_ID.tgz" -C "$artifact_dir"
  rm "$subdir/$ARTIFACT_ID.tgz"

  # Process configuration files
  process_config_files "$EUREKA_SERVER_NAME" "$KAFKA_SERVER_NAME" "$subdir" "$ARTIFACT_ID"

  # Build the project
  cd "$artifact_dir" || { echo "Failed to change directory to $artifact_dir"; return; }
  chmod +x ./gradlew
  if ! ./gradlew clean build --no-build-cache; then
    echo "Error: Build failed for $ARTIFACT_ID."
    cd - > /dev/null
    return
  fi
  cd - > /dev/null
}

start_kafka_container () {
 local kafka_container_id=$(docker run -d --name temp-kafka-container \
    -e KAFKA_CFG_LISTENERS="PLAINTEXT://:9092,CONTROLLER://:9093" \
    -e KAFKA_CFG_ADVERTISED_LISTENERS="PLAINTEXT://localhost:9092" \
    -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES="CONTROLLER" \
    -e KAFKA_CFG_PROCESS_ROLES="broker,controller" \
    -e KAFKA_CFG_NODE_ID="1" \
    -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS="1@localhost:9093" \
    -e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP="PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT" \
    -e KAFKA_CFG_LOG_DIRS="/tmp/kraft-combined-logs" \
    -e KAFKA_LOG4J_LOGGERS="kafka.controller=WARN,kafka.server=WARN,kafka.network=WARN" \
    -p 9092:9092 \
    -p 9093:9093 \
    bitnami/kafka:latest) 

  if [ $? -eq 0 ]; then
    echo "Kafka container started successfully with ID: $kafka_container_id"
  else
    echo "Failed to start Kafka container."
    exit 1
  fi

  # Step 2: Wait for Kafka to be ready
  echo "Waiting for Kafka to start..."
  sleep 10  # Replace with a check for readiness if needed
  echo "$kafka_container_id"
}
# Main logic
find "$JAVA_STACK_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
 if [[ "$subdir" == "$EUREKA_DIR" ]]; then
    process_directory "$subdir"
 fi
done

sleep 5
start_local_eureka
sleep 5

start_kafka_container
sleep 20

find "$JAVA_STACK_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
 if [[ "$subdir" == "$CONFIG_DIR" ]]; then
    process_directory "$subdir"
 fi
done

sleep 5
start_local_config
sleep 5

find "$JAVA_STACK_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
  [[ "$subdir" == "$EUREKA_DIR" || "$subdir" == "$CONFIG_DIR"  ]] && continue  # Skip Eureka directory
  process_directory "$subdir"
done

echo "All operations completed successfully."