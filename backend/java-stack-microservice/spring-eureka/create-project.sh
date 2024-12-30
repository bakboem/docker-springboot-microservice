#!/bin/bash



# Set variables for project generation
GROUP_ID="com.codera"
ARTIFACT_ID="eureka"
NAME="eureka"
DESCRIPTION="Eureka For Service Discovery System"
PACKAGE_NAME="com.codera.eureka"
BOOT_VERSION="3.4.1"
DEPENDENCIES="cloud-eureka,actuator,security"




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
  -d dependencies=${DEPENDENCIES} \
  -d packageName=${PACKAGE_NAME} \
  --output ${ARTIFACT_ID}.tgz

# Extract the project
tar -xzf ${ARTIFACT_ID}.tgz

# Change directory to the project folder
cd ${ARTIFACT_ID}



# 定义目标配置文件路径
CONFIG_DIR="src/main/resources"
PROPERTIES_FILE="$CONFIG_DIR/application.properties"
YAML_FILE="$CONFIG_DIR/application.yml"

# 检查并删除 application.properties 文件
if [ -f "$PROPERTIES_FILE" ]; then
  echo "Found $PROPERTIES_FILE. Deleting it."
  rm -f "$PROPERTIES_FILE"
fi

# 创建 application.yml 文件并写入配置
echo "Creating $YAML_FILE with the required configuration."
mkdir -p "$CONFIG_DIR"  # 确保目录存在
cat > "$YAML_FILE" <<EOF
server:
  port: 8761  # 设置 Eureka Server 监听的端口

eureka:
  client:
    register-with-eureka: false  # 不向自己或其他 Eureka Server 注册
    fetch-registry: false        # 不从其他 Eureka Server 拉取注册表
  server:
    enable-self-preservation: false  # 禁用自我保护模式（开发环境可禁用，生产建议保留）
EOF

echo "$YAML_FILE created successfully."

# Build the project to generate JAR file
echo "Running ./gradlew clean build..."
if ./gradlew clean build; then
  echo "Build completed successfully."
else
  echo "Error: Build failed."
  exit 1
fi

