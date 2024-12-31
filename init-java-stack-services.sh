#!/bin/bash
set -e 

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
  GROUP_ID=$(grep "^GROUP_ID:" "$config_file" | awk '{print $2}')
  ARTIFACT_ID=$(grep "^ARTIFACT_ID:" "$config_file" | awk '{print $2}')
  NAME=$(grep "^NAME:" "$config_file" | awk '{print $2}')
  DESCRIPTION=$(grep "^DESCRIPTION:" "$config_file" | awk -F': ' '{print $2}')
  PACKAGE_NAME=$(grep "^PACKAGE_NAME:" "$config_file" | awk '{print $2}')
  BOOT_VERSION=$(grep "^BOOT_VERSION:" "$config_file" | awk '{print $2}')
  DEPENDENCIES=$(grep "^DEPENDENCIES:" "$config_file" | awk -F': ' '{print $2}' | tr -d '[],' | tr '\n' ',' | sed 's/,$//')

  # 检查项目是否已经存在
  if [ -d "$subdir/$ARTIFACT_ID" ]; then
    echo "Directory '$ARTIFACT_ID' already exists in $subdir. Skipping project generation."
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

  mkdir -p "$subdir/$ARTIFACT_ID"
  tar -xzf "$subdir/$ARTIFACT_ID.tgz" -C "$subdir/$ARTIFACT_ID"
  rm "$subdir/$ARTIFACT_ID.tgz"

  # 移动 application.yml 文件到项目目录
  CONFIG_DIR="$subdir/$ARTIFACT_ID/src/main/resources"
  YAML_SOURCE="$subdir/application.yml"
  echo "Copying application.yml to $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
  cp "$YAML_SOURCE" "$CONFIG_DIR/application.yml"

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
  # 进入项目目录
  cd "$subdir/$ARTIFACT_ID"

  # 执行构建命令
  if ! ./gradlew clean build; then
    echo "Error: Build failed for $ARTIFACT_ID. Exiting."
    exit 1
  fi

  # 返回到原来的目录
  cd - > /dev/null
  echo "Project $ARTIFACT_ID setup completed."
done

echo "All operations completed successfully."


