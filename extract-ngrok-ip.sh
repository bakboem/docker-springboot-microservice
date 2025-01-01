set -e 

# 停止本地 运行中的 ngrok
if pgrep -x "ngrok" > /dev/null; then
  echo "Stopping running ngrok process..."
  killall ngrok
else
  echo "No running ngrok process found."
fi

# 检查 ngrok 是否正在监听端口 80
if ! curl -s http://127.0.0.1:4040/api/tunnels | jq -e '.tunnels[] | select(.config.addr == "http://localhost:80")' > /dev/null 2>&1; then
  echo "No active ngrok tunnel for port 80. Starting ngrok..."
  # 启动 ngrok 并后台运行，将输出保存到日志文件
  ngrok http 80 > ngrok.log 2>&1 &
  sleep 5 # 等待 ngrok 启动
fi
# 提取 ngrok 的公网 URL
PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[] | select(.config.addr == "http://localhost:80") | .public_url')
PUBLIC_URL_CLEANED=""
# 检查是否提取到 URL
if [ -n "$PUBLIC_URL" ]; then
  # 去掉 https:// 前缀
  PUBLIC_URL_CLEANED=$(echo "$PUBLIC_URL" | sed 's|https://||')

  echo "Cleaned Public URL: $PUBLIC_URL_CLEANED"

  # 替换 .env 文件中的 KAFKA_CFG_ADVERTISED_LISTENERS 配置
  ENV_FILE="./backend/nocode-standalone-instance/kafka/.env"
  sed -i.bak "s|^KAFKA_CFG_ADVERTISED_LISTENERS=.*|KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://$PUBLIC_URL_CLEANED:9092|" "$ENV_FILE"

  echo ".env file updated with: PLAINTEXT://$PUBLIC_URL_CLEANED:9092"
else
  echo "No public URL found. Please ensure ngrok is running and a tunnel is open."
fi