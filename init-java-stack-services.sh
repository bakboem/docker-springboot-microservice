#!/bin/bash
set -e 

# 设置主路径
JAVA_STACK_PATH="./backend/java-stack-microservice"
EUREKA_DIR="$JAVA_STACK_PATH/spring-eureka"
EUREKA_ARTIFACT_DIR="$EUREKA_DIR/eureka"
EUREKA_PID=""

start_ngrok (){
# 停止本地 运行中的 ngrok
if pgrep -x "ngrok" > /dev/null; then
  echo "Stopping running ngrok process..."
  killall ngrok
else
  echo "No running ngrok process found."
fi

# 检查 ngrok 是否正在监听端口 80
if ! curl -s http://127.0.0.1:4040/api/tunnels | jq -e '.tunnels[] | select(.config.addr == "http://localhost:80")' > /dev/null 2>&1; then
  echo "No active ngrok tunnel for port 80. Starting ngrok..."
  # 启动 ngrok 并后台运行，将输出保存到日志文件
  ngrok http 80 > ngrok.log 2>&1 &
  sleep 5 # 等待 ngrok 启动
fi
# 提取 ngrok 的公网 URL
PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[] | select(.config.addr == "http://localhost:80") | .public_url')
PUBLIC_URL_CLEANED=""
# 检查是否提取到 URL
if [ -n "$PUBLIC_URL" ]; then
  # 去掉 https:// 前缀
  PUBLIC_URL_CLEANED=$(echo "$PUBLIC_URL" | sed 's|https://||')

  echo "Cleaned Public URL: $PUBLIC_URL_CLEANED"

  # 替换 .env 文件中的 KAFKA_CFG_ADVERTISED_LISTENERS 配置
  ENV_FILE="./backend/nocode-standalone-instance/kafka/.env"
  sed -i.bak "s|^KAFKA_CFG_ADVERTISED_LISTENERS=.*|KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://$PUBLIC_URL_CLEANED:9092|" "$ENV_FILE"

  echo ".env file updated with: PLAINTEXT://$PUBLIC_URL_CLEANED:9092"
else
  echo "No public URL found. Please ensure ngrok is running and a tunnel is open."
fi
}

# Function to build and prepare the local Eureka server
# Function to build and prepare the local Eureka server dynamically
build_local_eureka() {
  # 检查 build-config.yml 是否存在
  local config_file="$EUREKA_DIR/build-config.yml"
  if [ ! -f "$config_file" ]; then
    echo "Skipping Eureka setup: Missing build-config.yml"
    return
  fi

  # 使用 yq 提取参数
  local GROUP_ID=$(yq '.GROUP_ID' "$config_file")
  local ARTIFACT_ID=$(yq '.ARTIFACT_ID' "$config_file")
  local NAME=$(yq '.NAME' "$config_file")
  local DESCRIPTION=$(yq '.DESCRIPTION' "$config_file")
  local BOOT_VERSION=$(yq '.BOOT_VERSION' "$config_file")
  local ADD_ANOTATION=$(yq '.ADD_ANOTATION' "$config_file")
  local ADD_IMPORT=$(yq '.ADD_IMPORT' "$config_file")
  local DEPENDENCIES=$(yq -r '.DEPENDENCIES[]' "$config_file" | paste -sd "," -)

  echo "Extracted dependencies: $DEPENDENCIES"

  # 如果目标目录不存在，则生成项目
  if [ ! -d "$EUREKA_ARTIFACT_DIR" ]; then
    echo "Eureka directory not found. Generating project..."
    mkdir -p "$EUREKA_ARTIFACT_DIR"

    curl "https://start.spring.io/starter.tgz" \
      -d type=gradle-project \
      -d language=java \
      -d bootVersion="$BOOT_VERSION" \
      -d groupId="$GROUP_ID" \
      -d artifactId="$ARTIFACT_ID" \
      -d name="$NAME" \
      -d description="$DESCRIPTION" \
      -d dependencies=$DEPENDENCIES \
      --output "$EUREKA_DIR/eureka-server.tgz"

    tar -xzf "$EUREKA_DIR/eureka-server.tgz" -C "$EUREKA_ARTIFACT_DIR"
    rm "$EUREKA_DIR/eureka-server.tgz"

    local config_dir="$EUREKA_ARTIFACT_DIR/src/main/resources"
    local yaml_source="$EUREKA_DIR/application.yml"
    local properties_file="$config_dir/application.properties"
    cp "$yaml_source" "$config_dir/application.yml"
    sed -i.bak "s|\$docker-service-name|http://localhost|g" "$config_dir/application.yml"
      rm "$config_dir/application.yml.bak"
    
    # 生成 Docker 用的 application.docker.yml
    local docker_config="$EUREKA_DIR/application.docker.yml"
    cp "$yaml_source" "$docker_config"
    # 替换 $docker-service-name 为 docker-compose 中 eureka 服务名称
    if grep -q "\$docker-service-name" "$docker_config"; then
      echo "Replacing \$docker-service-name with http://eureka in application.docker.yml"
      sed -i.bak "s|\$docker-service-name|http://eureka|g" "$docker_config"
      rm "$docker_config.bak"
    fi

    # 如果是 Eureka Server 项目，设置 hostname 为 eureka
    if grep -q "hostname: localhost" "$docker_config"; then
      echo "Updating hostname to eureka in application.docker.yml"
      sed -i.bak "s|hostname: localhost|hostname: eureka|g" "$docker_config"
      rm "$docker_config.bak"
    fi

    if [ -f "$properties_file" ]; then
      rm -rf "$properties_file"
      echo "Deleted $properties_file"
    fi
  fi

  # 检查是否需要添加 @EnableEurekaServer
  local eureka_application_file="$EUREKA_ARTIFACT_DIR/src/main/java/com/codera/eureka/EurekaServerApplication.java"

  if [ -f "$eureka_application_file" ]; then
    echo "Checking $eureka_application_file for @EnableEurekaServer..."
    
    # 如果 @EnableEurekaServer 不存在，则添加
    if ! grep -q "@EnableEurekaServer" "$eureka_application_file"; then
      echo "@EnableEurekaServer not found. Adding annotation and import..."
      
      # 添加 import
      if ! grep -q "import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;" "$eureka_application_file"; then
        sed -i.bak '1 a\
import org.springframework.cloud.netflix.eureka.server.EnableEurekaServer;' "$eureka_application_file"
      fi

      # 添加 @EnableEurekaServer
      sed -i.bak '/@SpringBootApplication/a\
@EnableEurekaServer\
' "$eureka_application_file"
      rm "$eureka_application_file.bak"
      echo "@EnableEurekaServer added."
    else
      echo "@EnableEurekaServer already present."
    fi
  else
    echo "EurekaServerApplication.java not found in $EUREKA_ARTIFACT_DIR"
    return 1
  fi

  echo "Building Eureka server..."
  cd "$EUREKA_ARTIFACT_DIR" || { echo "Failed to change directory to $EUREKA_ARTIFACT_DIR"; exit 1; }
  chmod +x ./gradlew
  if ! ./gradlew clean build --no-build-cache; then
    echo "Error: Build failed for Eureka server."
    exit 1
  fi
  cd - > /dev/null
}


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
process_config_files() {
  local config_dir="$1"
  local yaml_source="$2"
  local properties_file="$config_dir/application.properties"

  echo "Processing configuration files in $config_dir"

  mkdir -p "$config_dir"
  if [ -f "$yaml_source" ]; then
    echo "Copying application.yml to $config_dir"
    cp "$yaml_source" "$config_dir/application.yml"

    if grep -q "\$docker-service-name" "$config_dir/application.yml"; then
      echo "\$docker-service-name found in application.yml. Replacing with http://localhost"
      sed -i.bak "s|\$docker-service-name|http://localhost|g" "$config_dir/application.yml"
      rm "$config_dir/application.yml.bak"
    fi
  else
    echo "Warning: $yaml_source does not exist. Skipping application.yml replacement."
  fi

  if [ -f "$properties_file" ]; then
    echo "Deleting $properties_file"
    rm -f "$properties_file"
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
  local ADD_ANOTATION=$(yq '.ADD_ANOTATION' "$config_file")
  local ADD_IMPORT=$(yq '.ADD_IMPORT' "$config_file")
  local DEPENDENCIES=$(yq -r '.DEPENDENCIES[]' "$config_file" | paste -sd "," -)

  echo "Processing $ARTIFACT_ID in $subdir"

  local artifact_dir="$subdir/$ARTIFACT_ID"
  local config_dir="$artifact_dir/src/main/resources"
  local yaml_source="$subdir/application.yml"

  
  # 生成 Docker 用的 application.docker.yml
  local docker_config="$subdir/application.docker.yml"
  cp "$yaml_source" "$docker_config"
  # 替换 $docker-service-name 为 docker-compose 中 eureka 服务名称
  if grep -q "\$docker-service-name" "$docker_config"; then
    echo "Replacing \$docker-service-name with http://eureka in application.docker.yml"
    sed -i.bak "s|\$docker-service-name|http://eureka|g" "$docker_config"
    rm "$docker_config.bak"
  fi

  # Check if project directory exists
  if [ -d "$artifact_dir" ]; then
    echo "Directory '$ARTIFACT_ID' already exists in $subdir."
    process_config_files "$config_dir" "$yaml_source"

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
  process_config_files "$config_dir" "$yaml_source"

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

# Main logic
start_ngrok
build_local_eureka
start_local_eureka

find "$JAVA_STACK_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
  [[ "$subdir" == "$EUREKA_DIR" ]] && continue  # Skip Eureka directory
  process_directory "$subdir"
done

stop_local_eureka

echo "All operations completed successfully."