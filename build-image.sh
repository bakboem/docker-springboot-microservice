#!/bin/bash
set -e 
if ./init-java-stack-services.sh; then
  echo "init-java-stack-services.sh executed successfully."
else
  echo "Error: init-java-stack-services.sh did not complete successfully."
  exit 1
fi

# 如果备份文件存在，恢复备份文件
if [ -f ./docker-compose-dev.yml.bak ]; then
  echo "恢复备份文件 docker-compose-dev.yml.bak 到 docker-compose-dev.yml"
  cp ./docker-compose-dev.yml.bak ./docker-compose-dev.yml
else
  echo "未找到备份文件 docker-compose-dev.yml.bak,继续执行。"
fi

# 运行 docker-compose build
# docker-compose -f ./docker-compose-dev.yml --profile standalone --profile java-microservices build
docker-compose -f ./docker-compose-dev.yml --profile java-microservices build
if [ $? -ne 0 ]; then
  echo "构建过程中出现错误，退出脚本。"
  exit 1
fi

# 备份原始文件
cp ./docker-compose-dev.yml ./docker-compose-dev.yml.bak

# 使用 sed 注释掉 build 和 context 部分
sed -i '' '/build:/,/^[[:space:]]*context:/{
  # 注释掉 build 和 context 部分
  s/^\(.*\)/# &/
}' ./docker-compose-dev.yml

# 使用 sed 添加 image 字段（从 container_name 提取并添加），保留 container_name
sed -i '' '/container_name:/{
  # 提取 container_name 后面的值并添加 image 字段，同时保留 container_name
  s/^.*container_name: \(.*\)/    image: \1\n    container_name: \1/
}' ./docker-compose-dev.yml

echo "docker-compose-dev.yml 文件已更新, build 和 context 部分已注释，并添加了 image 字段，同时保留了 container_name。"
