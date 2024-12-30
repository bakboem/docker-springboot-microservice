./extract-ngrok-ip.sh
./create-jwt-token-keypair.sh
# docker-compose -f ./docker-compose-dev.yml --profile standalone --profile java-microservices up -d 
docker-compose -f ./docker-compose-dev.yml --profile java-microservices up -d 