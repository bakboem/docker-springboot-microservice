#!/bin/bash
set -e

influxd &

INFLUXDB_PID=$!

echo "waiting InfluxDB ..."
MAX_RETRIES=30  
RETRY_INTERVAL=2  

count=0
until curl -sL http://localhost:8086/ping > /dev/null; do
  sleep $RETRY_INTERVAL
  count=$((count+1))
  if [ $count -ge $MAX_RETRIES ]; then
    echo "InfluxDB startup delay!"
    kill $INFLUXDB_PID
    exit 1
  fi
done

check_user_exists() {
  local username=$1
  local admin_token=$2
  local response=$(curl -s -X GET http://localhost:8086/api/v2/users?name=$username -H "Authorization: Token ${admin_token}")
  local user_exists=$(echo $response | jq -e '.users[] | select(.name=="'"$username"'")' > /dev/null; echo $?)
  return $user_exists
}

create_user() {
  local username=$1
  local password=$2
  local admin_token=$3
  local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8086/api/v2/users -H "Authorization: Token ${admin_token}" -H "Content-type: application/json" -d '{"name":"'"$username"'", "password":"'"$password"'"}')
  echo $response
}

check_org_exists() {
  local org_name=$1
  local admin_token=$2
  local response=$(curl -s -X GET "http://localhost:8086/api/v2/orgs" -H "Authorization: Token ${admin_token}")
  local org_id=$(echo $response | jq -r '.orgs[] | select(.name=="'"$org_name"'").id')
  echo $org_id
}

create_org() {
  local org_name=$1
  local admin_token=$2
  local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8086/api/v2/orgs -H "Authorization: Token ${admin_token}" -H "Content-type: application/json" -d '{"name":"'"$org_name"'"}')
  echo $response
}

check_bucket_exists() {
  local bucket_name=$1
  local org_id=$2
  local admin_token=$3
  local response=$(curl -s -X GET "http://localhost:8086/api/v2/buckets?orgID=$org_id&name=$bucket_name" -H "Authorization: Token ${admin_token}")
  local bucket_exists=$(echo $response | jq -e '.buckets[] | select(.name=="'"$bucket_name"'")' > /dev/null; echo $?)
  return $bucket_exists
}

create_bucket() {
  local bucket_name=$1
  local org_id=$2
  local admin_token=$3
  local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:8086/api/v2/buckets -H "Authorization: Token ${admin_token}" -H "Content-type: application/json" -d '{"name":"'"$bucket_name"'", "orgID":"'"$org_id"'", "retentionRules":[{"type":"expire","everySeconds":3600}]}')
  echo $response
}

# 检查是否已经初始化
INIT_FLAG="/var/lib/influxdb2/.initialized"

if [ -f "$INIT_FLAG" ]; then
  echo "InfluxDB has already been initialized, skipping setup step"

  # 检查用户是否存在
  if check_user_exists $DOCKER_INFLUXDB_INIT_USERNAME $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN; then
    echo "the user exist"
  else
    response=$(create_user $DOCKER_INFLUXDB_INIT_USERNAME $DOCKER_INFLUXDB_INIT_PASSWORD $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)
    if [ "$response" == "201" ]; then
      echo "create user successful."
    else
      echo "create user faild, HTTP statusCode:$response"
    fi
  fi

  # 检查组织是否存在
  org_id=$(check_org_exists $DOCKER_INFLUXDB_INIT_ORG $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)
  if [ -z "$org_id" ]; then
    response=$(create_org $DOCKER_INFLUXDB_INIT_ORG $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)
    if [ "$response" == "201" ]; then
      echo "Org create successful."
      org_id=$(check_org_exists $DOCKER_INFLUXDB_INIT_ORG $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)
    else
      echo "create Org faild, HTTP statusCode:$response"
    fi
  else
    echo "Org exist"
  fi

  # 检查桶是否存在
  if check_bucket_exists $DOCKER_INFLUXDB_INIT_BUCKET $org_id $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN; then
    echo "bucket exist"
  else
    response=$(create_bucket $DOCKER_INFLUXDB_INIT_BUCKET $org_id $DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)
    if [ "$response" == "201" ]; then
      echo "create bucket successful."
    else
      echo "create bucket faild, HTTP statusCode : $response"
    fi
  fi

else
  echo "init InfluxDB"
  
  influx setup --bucket "${DOCKER_INFLUXDB_INIT_BUCKET}" \
               --org "${DOCKER_INFLUXDB_INIT_ORG}" \
               --username "${DOCKER_INFLUXDB_INIT_USERNAME}" \
               --password "${DOCKER_INFLUXDB_INIT_PASSWORD}" \
               --token "${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}" \
               --force
  
  if [ $? -eq 0 ]; then
    touch "$INIT_FLAG"
    echo "InfluxDB init successful"
  else
    echo "InfluxDB init faild"
    kill $INFLUXDB_PID
    exit 1
  fi
fi

# 等待 InfluxDB 服务进程结束
wait $INFLUXDB_PID
