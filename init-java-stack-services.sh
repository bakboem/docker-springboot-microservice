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

  if [ ! -f "$build_script" ]; then
    echo "Skipping $subdir: Missing build-jar.sh"
    continue
  fi

  if [ ! -f "$create_script" ]; then
    echo "Skipping $subdir: Missing create-project.sh"
    continue
  fi

  # 添加执行权限
  chmod +x "$build_script" "$create_script"
  echo "Set executable permissions for $build_script and $create_script"


  # 检查是否存在 ARTIFACT_ID 为名的文件夹
  gradle_dir="$subdir/.gradle"
  if [ -d "$gradle_dir" ]; then
    echo "Directory .gradle exists in $subdir. Executing only build-jar.sh"
    (cd "$subdir" && bash "./build-jar.sh") || { echo "Error: Failed to execute build-jar.sh in $subdir"; exit 1; }
  else
    echo "Directory .gradle does not exist in $subdir. Executing create-project.sh and build-jar.sh"
    (cd "$subdir" && bash "./create-project.sh") || { echo "Error: Failed to execute create-project.sh in $subdir"; exit 1; }
done

echo "All operations completed successfully."
