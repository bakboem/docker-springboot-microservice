./create-jwt-token-keypair.sh
./build-image.sh

# Start all profile
# docker-compose -f ./docker-compose-dev.yml --profile standalone --profile java-microservices up -d 

# Start Selected profile
docker-compose -f ./docker-compose-dev.yml --profile java-microservices  up -d 