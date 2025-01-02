# 基于官方 Bitnami Kafka 镜像
FROM bitnami/kafka:latest

# 临时切换到 root 用户
USER root

# 安装 netcat-openbsd
RUN apt-get update && apt-get install -y netcat-openbsd && apt-get clean
# 切换回默认用户（通常为 1001）
USER 1001
# 暴露 Kafka 默认端口
EXPOSE 9092
EXPOSE 9093
EXPOSE 8082



