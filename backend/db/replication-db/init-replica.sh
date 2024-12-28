#!/bin/bash
set -e

# 主库连接信息
MASTER_HOST="main-db"        # 主库的主机名或 IP 地址
MASTER_PORT="5432"           # 主库的端口号
REPLICA_USER=$POSTGRES_USER  # 使用 Dockerfile 中的用户
REPLICA_PASSWORD=$POSTGRES_PASSWORD

# 流复制数据存放路径
PGDATA="/var/lib/postgresql/data"

echo "Starting replication setup for PostgreSQL..."

# 检查是否已经存在有效的从库数据目录
if [ -f "${PGDATA}/standby.signal" ]; then
    echo "Replication is already configured. Skipping initialization."
    exit 0
fi

# 检查主库是否可以连接
PGPASSWORD=${REPLICA_PASSWORD} psql -h ${MASTER_HOST} -p ${MASTER_PORT} -U ${REPLICA_USER} -c "SELECT 1;" || {
    echo "Error: Unable to connect to the master database. Please check the connection settings."
    exit 1
}

# 清空 PGDATA（仅在未初始化时）
echo "Cleaning up existing data directory..."
rm -rf ${PGDATA}/*

# 使用 pg_basebackup 从主库获取数据快照
echo "Starting pg_basebackup from master database..."
PGPASSWORD=${REPLICA_PASSWORD} pg_basebackup \
    -h ${MASTER_HOST} \
    -p ${MASTER_PORT} \
    -U ${REPLICA_USER} \
    -D ${PGDATA} \
    -Fp \
    -Xs \
    -P || {
        echo "Error: pg_basebackup failed. Please check the master database and credentials."
        exit 1
    }

echo "pg_basebackup completed. Configuring replication mode..."

# 创建 standby.signal 文件以启用流复制（PostgreSQL 12+）
touch ${PGDATA}/standby.signal

# 配置恢复参数
cat > ${PGDATA}/postgresql.auto.conf <<EOF
primary_conninfo = 'host=${MASTER_HOST} port=${MASTER_PORT} user=${REPLICA_USER} password=${REPLICA_PASSWORD}'
primary_slot_name = 'replication_slot'
EOF

# 设置权限
echo "Setting permissions for PGDATA directory..."
chown -R postgres:postgres ${PGDATA}
chmod 700 ${PGDATA}

echo "Replication setup complete. PostgreSQL is ready to start in replication mode."
