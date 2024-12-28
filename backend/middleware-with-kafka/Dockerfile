# 使用官方 Kafka 镜像
FROM bitnami/kafka:latest

# 设置时区
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置工作目录
WORKDIR /kafka

# 暴露 Kafka 默认端口
EXPOSE 9092

# 启动 Kafka 服务
CMD ["/opt/bitnami/scripts/kafka/entrypoint.sh"]
