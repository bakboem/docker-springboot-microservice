#!/bin/bash

# 配置密钥目录和文件名
KEY_DIR="./backend/nocode-standalone-instance/monitoring/grafana"
PRIVATE_KEY_FILE="$KEY_DIR/private.pem"
PUBLIC_KEY_FILE="$KEY_DIR/grafana_public_key.pem"

# 检查密钥目录是否存在，不存在则创建
if [ ! -d "$KEY_DIR" ]; then
  echo "Creating directory for JWT keys: $KEY_DIR"
  mkdir -p "$KEY_DIR"
fi

# 检查是否已有密钥对，避免重复生成
if [ -f "$PRIVATE_KEY_FILE" ] && [ -f "$PUBLIC_KEY_FILE" ]; then
  echo "Keys already exist:"
  echo "Private Key: $PRIVATE_KEY_FILE"
  echo "Public Key: $PUBLIC_KEY_FILE"
  exit 0
fi

# 生成 RSA 私钥
echo "Generating RSA private key..."
openssl genrsa -out "$PRIVATE_KEY_FILE" 2048

# 提取公钥
echo "Extracting public key from private key..."
openssl rsa -in "$PRIVATE_KEY_FILE" -pubout -out "$PUBLIC_KEY_FILE"

# 设置权限
echo "Setting permissions for keys..."
chmod 400 "$PRIVATE_KEY_FILE"
chmod 444 "$PUBLIC_KEY_FILE"

echo "Key generation complete."
echo "Private Key: $PRIVATE_KEY_FILE"
echo "Public Key: $PUBLIC_KEY_FILE"
