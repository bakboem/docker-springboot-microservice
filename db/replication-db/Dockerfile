# 使用 PostgreSQL 官方镜像
FROM postgres:13-alpine

# 设置时区
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


# 复制从库初始化脚本
COPY ./init-replica.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-replica.sh

# 暴露默认端口
EXPOSE 5432
