#!/bin/bash
# USE: ./deploy.sh NUM_STORAGE NUM_EVM NUM_CLIENTS

DOCKER_USER=$(cat config.yaml | shyaml get-value docker_user)
DOCKER_PASS=$(cat config.yaml | shyaml get-value docker_pass)
docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}

start_storage() {
    /bin/bash deploy_storage.sh $1
}

start_evm() {
    /bin/bash deploy_evm.sh $1
}

start_client() {
    /bin/bash deploy_client.sh $1
}

start_storage $1
start_evm $2
start_client $3