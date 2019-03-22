#!/bin/bash
# Dependency - shyaml. pip install shyaml.
# USE: ./deploy.sh NUM_STORAGE NUM_EVM NUM_CLIENTS

DOCKER_USER=$(cat config.yaml | shyaml get-value docker_user)
DOCKER_PASS=$(cat config.yaml | shyaml get-value docker_pass)
docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}

# build_evm() {
#     cd ../evmc-js
#     docker build . -t rainblock/rainblock:evm
#     docker push rainblock/rainblock:evm
# }

build_test_verifier_storage() {
    cd test_verifier_storage
    rm -rf rainblock-storage
    git clone git@gitlab.com:SoujanyaPonnapalli/rainblock-storage.git
    cd rainblock-storage && git branch dockertest && cd ..
    zip -r rainblock-storage.zip rainblock-storage
    docker build . -t ${DOCKER_USER}/rainblock:testVerifStore
    docker push ${DOCKER_USER}/rainblock:testVerifStore
    cd ..
}

build_test_client_storage() {
    cd test_client_storage
    rm -rf rainblock-storage
    git clone git@gitlab.com:SoujanyaPonnapalli/rainblock-storage.git
    cd rainblock-storage && git branch dockertest && cd ..
    zip -r rainblock-storage.zip rainblock-storage
    docker build . -t ${DOCKER_USER}/rainblock:testCliStore
    docker push ${DOCKER_USER}/rainblock:testVerifStore
    cd ..
}

build_storage() {
    cd storage
    rm -rf rainblock-storage
    git clone git@gitlab.com:SoujanyaPonnapalli/rainblock-storage.git
    cd rainblock-storage && git branch dockertest && cd ..
    zip -r rainblock-storage.zip rainblock-storage
    docker build . -t ${DOCKER_USER}/rainblock:mainStore
    docker push ${DOCKER_USER}/rainblock:mainStore
    cd ..
}

build_storage
build_test_verifier_storage
build_test_client_storage