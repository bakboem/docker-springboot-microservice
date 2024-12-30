# Stop all profile
# docker-compose -f ./docker-compose-dev.yml --profile standalone --profile java-microservices down

# Stop Selected profile
docker-compose -f ./docker-compose-dev.yml  --profile java-microservices down