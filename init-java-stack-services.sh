#!/bin/bash

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

  # 检查是否存在 build-jar.sh 和 create-project.sh
  build_script="$subdir/build-jar.sh"
  create_script="$subdir/create-project.sh"

  if [ ! -f "$build_script" ] || [ ! -f "$create_script" ]; then
    echo "Skipping $subdir: Missing build-jar.sh or create-project.sh"
    continue
  fi

  # 添加执行权限
  chmod +x "$build_script" "$create_script"
  echo "Set executable permissions for $build_script and $create_script"

  # 从 build-jar.sh 中提取 ARTIFACT_ID
  artifact_id=$(grep '^ARTIFACT_ID=' "$build_script" | cut -d'=' -f2 | tr -d '"')
  if [ -z "$artifact_id" ]; then
    echo "Error: ARTIFACT_ID not defined in $build_script"
    continue
  fi

  # 检查是否存在 ARTIFACT_ID 为名的文件夹
  if [ -d "$subdir/$artifact_id" ]; then
    echo "Directory $artifact_id exists. Executing only build-jar.sh"
    bash "$build_script" || { echo "Error: Failed to execute $build_script"; exit 1; }
  else
    echo "Directory $artifact_id does not exist. Executing create-project.sh and build-jar.sh"
    bash "$create_script" || { echo "Error: Failed to execute $create_script"; exit 1; }
    bash "$build_script" || { echo "Error: Failed to execute $build_script"; exit 1; }
  fi
done

echo "All operations completed successfully."
