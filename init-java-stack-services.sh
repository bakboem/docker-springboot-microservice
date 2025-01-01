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
build_local_eureka() {
  if [ ! -d "$EUREKA_ARTIFACT_DIR" ]; then
    echo "Eureka directory not found. Generating project..."
    mkdir -p "$EUREKA_ARTIFACT_DIR"

    curl "https://start.spring.io/starter.tgz" \
      -d type=gradle-project \
      -d language=java \
      -d bootVersion=3.4.1 \
      -d groupId=com.example \
      -d artifactId=eureka-server \
      -d name=EurekaServer \
      -d description="Eureka Server for Service Discovery" \
      -d dependencies=cloud-eureka-server \
      --output "$EUREKA_DIR/eureka-server.tgz"

    tar -xzf "$EUREKA_DIR/eureka-server.tgz" -C "$EUREKA_ARTIFACT_DIR"
    rm "$EUREKA_DIR/eureka-server.tgz"
    # copy
    local config_dir="$EUREKA_ARTIFACT_DIR/src/main/resources"
    local yaml_source="$EUREKA_DIR/application.yml"
    local properties_file="$config_dir/application.properties"
    cp "$yaml_source" "$config_dir/application.yml"

    if [ -f "$properties_file" ];then
      rm -rf "$properties_file"
      echo "Delete $properties_file. Done"
    fi
  fi

  echo "Building Eureka server..."
  cd "$EUREKA_ARTIFACT_DIR" || { echo "Failed to change directory to $EUREKA_ARTIFACT_DIR"; exit 1; }
  chmod +x ./gradlew
  if ! ./gradlew clean build; then
    echo "Error: Build failed for Eureka server."
    exit 1
  fi
  cd - > /dev/null
}

# Function to start the local Eureka server
start_local_eureka() {
  echo "Starting local Eureka server..."
  java -jar "$EUREKA_DIR/build/libs/eureka-server-0.0.1-SNAPSHOT.jar" &
  EUREKA_PID=$!
  echo "Eureka server started with PID $EUREKA_PID"
  sleep 10  # Wait for Eureka to stabilize
}

# Function to stop the local Eureka server
stop_local_eureka() {
  if [ -n "$EUREKA_PID" ]; then
    echo "Stopping local Eureka server with PID $EUREKA_PID"
    kill "$EUREKA_PID"
    EUREKA_PID=""
  fi
}

# Function to process a single project directory
process_directory() {
  local subdir="$1"

  # 检查是否存在 build-config.yml 文件
  local config_file="$subdir/build-config.yml"
  if [ ! -f "$config_file" ]; then
    echo "Skipping $subdir: Missing build-config.yml"
    return
  fi

  # 提取配置参数
  local GROUP_ID=$(grep "^GROUP_ID:" "$config_file" | awk -F': ' '{print $2}')
  local ARTIFACT_ID=$(grep "^ARTIFACT_ID:" "$config_file" | awk -F': ' '{print $2}')
  local NAME=$(grep "^NAME:" "$config_file" | awk -F': ' '{print $2}')
  local DESCRIPTION=$(grep "^DESCRIPTION:" "$config_file" | awk -F': ' '{print $2}')
  local PACKAGE_NAME=$(grep "^PACKAGE_NAME:" "$config_file" | awk -F': ' '{print $2}')
  local BOOT_VERSION=$(grep "^BOOT_VERSION:" "$config_file" | awk -F': ' '{print $2}')
  local DEPENDENCIES=$(awk '/^DEPENDENCIES:/ {flag=1; next} /^[^ ]/ {flag=0} flag {print}' "$config_file" | tr -d '-' | tr -d ' ' | paste -sd ',' -)
  DEPENDENCIES=$(echo "$DEPENDENCIES" | sed 's/cloudconfigserver/cloud-config-server/g; s/cloudconfigclient/cloud-config-client/g; s/cloudeureka/cloud-eureka/g')

  echo "Processing $ARTIFACT_ID in $subdir"

  local artifact_dir="$subdir/$ARTIFACT_ID"
  local config_dir="$artifact_dir/src/main/resources"
  local yaml_source="$subdir/application.yml"
  local properties_file="$config_dir/application.properties"
  # 检查项目是否已经存在
  if [ -d "$artifact_dir" ]; then
    echo "Directory '$ARTIFACT_ID' already exists in $subdir."
    if [ -f "$yaml_source" ]; then
      echo "Copying application.yml to $config_dir"
      mkdir -p "$config_dir"
      cp "$yaml_source" "$config_dir/application.yml"
      

      if grep -q "\$ngrok-ip" "$config_dir/application.yml"; then
        echo "\$ngrok-ip found in application.yml. Replacing with http://localhost"
        sed -i.bak "s|\$ngrok-ip|http://localhost|g" "$config_dir/application.yml"
        rm "$config_dir/application.yml.bak"
      fi

      # 进入项目目录并执行构建命令
      cd "$artifact_dir"
      chmod +x ./gradlew
      if ! ./gradlew clean build; then
        echo "Error: Build failed for $ARTIFACT_ID."
        cd - > /dev/null
        return
      fi
      cd - > /dev/null
    else
      echo "Warning: $yaml_source does not exist. Skipping application.yml replacement."
    fi
    return
  fi

  # 下载并解压 Spring Boot 项目
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

  if [ -f "$yaml_source" ]; then
    echo "Copying application.yml to $config_dir"
    mkdir -p "$config_dir"
    cp "$yaml_source" "$config_dir/application.yml"
    if [ -f "$properties_file" ];then
      rm -rf "$properties_file"
      echo "Delete $properties_file. Done"
    fi
  else
    echo "Warning: $yaml_source does not exist. Skipping application.yml replacement."
  fi
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