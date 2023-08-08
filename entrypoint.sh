#!/bin/sh

# check if required paramethers provided
if [ -z "$INPUT_SSH_KEY" ]; then
  echo "Input ssh_key is required!"
  exit 1
fi

if [ -z "$INPUT_SSH_USER" ]; then
  echo "Input ssh_user is required!"
  exit 1
fi

if [ -z "$INPUT_SSH_HOST" ]; then
  echo "Input ssh_host is required!"
  exit 1
fi

# set correct values to paramethers
if [ "$INPUT_BUILD" == 'true' ]; then
  INPUT_BUILD='--build'
else
  INPUT_BUILD=''
fi

if [ "$INPUT_FORCE_RECREATE" == 'true' ]; then
  INPUT_FORCE_RECREATE='--force-recreate'
else
  INPUT_FORCE_RECREATE=''
fi

# set INPUT_COMPOSE_FILE variable if not provided
if [ -z "$INPUT_COMPOSE_FILE" ]; then
  INPUT_COMPOSE_FILE='docker-compose.yml'
fi

# set INPUT_SSH_PORT variable if not provided
if [ -z "$INPUT_SSH_PORT" ]; then
  INPUT_SSH_PORT=22
fi

if [ ! -z "$INPUT_ENV_FILE" ]; then
  INPUT_ENV_FILE_FLAG="--env-file $INPUT_ENV_FILE"
fi

if [ ! -z "$INPUT_PROJECT_NAME" ]; then
  INPUT_PROJECT_NAME="-p $INPUT_PROJECT_NAME"
fi

# create private key and add it to authentication agent

eval $(ssh-agent -s)
echo "$INPUT_SSH_KEY" | tr -d '\r' | printf '%s\n' - | ssh-add -

mkdir -p /root/.ssh
touch /root/.ssh/known_hosts
ssh-keyscan -H "$INPUT_SSH_HOST" >> /root/.ssh/known_hosts

# create remote context in docker and switch to it
docker context create remote --docker "host=ssh://$INPUT_SSH_USER@$INPUT_SSH_HOST:$INPUT_SSH_PORT"
docker context use remote

if [ ! -z "$INPUT_REGISTRY" ] && [ ! -z "$INPUT_REGISTRY_USERNAME" ] && [ ! -z "$INPUT_REGISTRY_PASSWORD" ]; then
  echo "$INPUT_REGISTRY_PASSWORD" | docker login --username "$INPUT_REGISTRY_USERNAME" --password-stdin "$INPUT_REGISTRY"
fi

# pull latest images if paramether provided
if [ "$INPUT_PULL" == 'true' ]; then
  docker compose -f $INPUT_COMPOSE_FILE $INPUT_ENV_FILE_FLAG $INPUT_PROJECT_NAME pull
fi
# deploy stack
docker compose -f $INPUT_COMPOSE_FILE $INPUT_ENV_FILE_FLAG $INPUT_PROJECT_NAME up -d $INPUT_BUILD $INPUT_FORCE_RECREATE $INPUT_OPTIONS $INPUT_SERVICE

# cleanup context
docker context use default 
docker context rm remote
