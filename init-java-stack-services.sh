#!/bin/bash
set -e 
echo "qqq"
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

# 设置主路径
export JAVA_STACK_PATH="./backend/java-stack-microservice"

# 检查主路径是否存在
if [ ! -d "$JAVA_STACK_PATH" ]; then
  echo "Error: Directory $JAVA_STACK_PATH does not exist."
  exit 1
fi

# 遍历 JAVA_STACK_PATH 目录下的所有子目录
find "$JAVA_STACK_PATH" -mindepth 1 -maxdepth 1 -type d | while read -r subdir; do
  echo "Processing directory: $subdir"

  # 检查是否存在 build-config.yml 文件
  config_file="$subdir/build-config.yml"
  if [ ! -f "$config_file" ]; then
    echo "Skipping $subdir: Missing build-config.yml"
    continue
  fi

  # 提取配置参数
  GROUP_ID=$(grep "^GROUP_ID:" "$config_file" | awk -F': ' '{print $2}')
  ARTIFACT_ID=$(grep "^ARTIFACT_ID:" "$config_file" | awk -F': ' '{print $2}')
  NAME=$(grep "^NAME:" "$config_file" | awk -F': ' '{print $2}')
  DESCRIPTION=$(grep "^DESCRIPTION:" "$config_file" | awk -F': ' '{print $2}')
  PACKAGE_NAME=$(grep "^PACKAGE_NAME:" "$config_file" | awk -F': ' '{print $2}')
  BOOT_VERSION=$(grep "^BOOT_VERSION:" "$config_file" | awk -F': ' '{print $2}')
  SERVER_PORT=$(grep "^SERVER_PORT:" "$config_file" | awk -F': ' '{print $2}')
  DEPENDENCIES=$(awk '/^DEPENDENCIES:/ {flag=1; next} /^[^ ]/ {flag=0} flag {print}' "$config_file" | tr -d '-' | tr -d ' ' | paste -sd ',' -)
  DEPENDENCIES=$(echo "$DEPENDENCIES" | sed 's/cloudconfigserver/cloud-config-server/g; s/cloudconfigclient/cloud-config-client/g; s/cloudeureka/cloud-eureka/g')

  echo "GROUP_ID: $GROUP_ID"
  echo "ARTIFACT_ID: $ARTIFACT_ID"
  echo "NAME: $NAME"
  echo "DESCRIPTION: $DESCRIPTION"
  echo "PACKAGE_NAME: $PACKAGE_NAME"
  echo "BOOT_VERSION: $BOOT_VERSION"
  echo "SERVER_PORT: $SERVER_PORT"
  echo "DEPENDENCIES: $DEPENDENCIES"
  # 检查项目是否已经存在
  if [ -d "$subdir/$ARTIFACT_ID" ]; then
    echo "Directory '$ARTIFACT_ID' already exists in $subdir. Skipping project generation."
    CONFIG_DIR="$subdir/$ARTIFACT_ID/src/main/resources"
    YAML_SOURCE="$subdir/application.yml"
    if [ -f "$YAML_SOURCE" ]; then
      # 如果存在 则 替换ngrok ip 到 application.yml 中的占位符
      echo "Copying application.yml to $CONFIG_DIR"
      cp "$YAML_SOURCE" "$CONFIG_DIR/application.yml"
      # 检查并替换 $ngrok-ip 占位符
      SAFE_NGROK_URL=$(echo "$PUBLIC_URL" | sed 's/[&/\]/\\&/g')
      echo "Replacing \$ngrok-ip in application.yml with $SAFE_NGROK_URL"
      sed -i.bak "s|\$ngrok-ip|$SAFE_NGROK_URL|g" "$CONFIG_DIR/application.yml"
      rm "$CONFIG_DIR/application.yml.bak"

      # 进入项目目录并执行构建命令
      cd "$subdir/$ARTIFACT_ID" || { echo "Failed to change directory to $subdir/$ARTIFACT_ID"; exit 1; }
   

      chmod +x ./gradlew
      if ! ./gradlew clean build; then
        echo "Error: Build failed for $ARTIFACT_ID. Returning to original directory."
        cd - > /dev/null || exit 1
        exit 1
      fi
    
      # 无论成功或失败都返回原目录
      cd - > /dev/null || exit 1
    else
      echo "Warning: $YAML_SOURCE does not exist. Skipping application.yml replacement."
    fi
    continue
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
    continue
  fi

  mkdir -p "$subdir/$ARTIFACT_ID"
  tar -xzf "$subdir/$ARTIFACT_ID.tgz" -C "$subdir/$ARTIFACT_ID"
  rm "$subdir/$ARTIFACT_ID.tgz"

  # 移动 application.yml 文件到项目目录
  CONFIG_DIR="$subdir/$ARTIFACT_ID/src/main/resources"
  YAML_SOURCE="$subdir/application.yml"
  if [ -f "$YAML_SOURCE" ]; then
    echo "Copying application.yml to $CONFIG_DIR"
    cp "$YAML_SOURCE" "$CONFIG_DIR/application.yml"
  else
    echo "Warning: $YAML_SOURCE does not exist. Skipping..."
  fi

  REPO_SOURCE="$subdir/config-repo"
  if [ -d "$REPO_SOURCE" ]; then
    echo "Copying directory $REPO_SOURCE to $CONFIG_DIR"
    cp -r "$REPO_SOURCE" "$CONFIG_DIR/"
  else
    echo "$REPO_SOURCE is not a directory or does not exist. Skipping..."
  fi

  # 删除无用的 .properties 文件
  PROPERTIES_FILE="$CONFIG_DIR/application.properties"
  if [ -f "$PROPERTIES_FILE" ]; then
    echo "Found $PROPERTIES_FILE. Deleting it."
    rm -f "$PROPERTIES_FILE"
  fi

  # 进入项目目录并执行构建命令
  cd "$subdir/$ARTIFACT_ID"
  chmod +x ./gradlew
  if ! ./gradlew clean build; then
    echo "Error: Build failed for $ARTIFACT_ID. Exiting."
    exit 1
  fi
  cd - > /dev/null

  echo "Project $ARTIFACT_ID setup completed."
done

echo "All operations completed successfully."
