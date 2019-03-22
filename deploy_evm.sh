#!/bin/bash
# Usage - ./deploy_storage.sh NUM_EVM_SERVICES

USERNAME=cc
DOCKER_USER=$(cat config.yaml | shyaml get-value docker_user)
DOCKER_PASS=$(cat config.yaml | shyaml get-value docker_pass)
ESERVERS=($(cat config.yaml | shyaml get-values evm_nodes))
PORT=6000
DIST=()
N=4
setup_docker_deps() {
  echo "Setting up docker"
	for ((i = 0; i < ${#ESERVERS[@]}; i++)); do
		if [[ "$i" -lt "$1" ]]
		then
			# Setup docker only if docker not already present
			ssh ${USERNAME}@${ESERVERS[i]} '
			if [ -x "$(command -v docker)" ]; then
				:
			else
				(curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - ) &> /dev/null
				sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &> /dev/null
				sudo apt-get update &> /dev/null
				sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu &> /dev/null
				sudo usermod -a -G docker $USER  &> /dev/null
			fi
			'
		fi
	done
}

# Gives the number of containers in each machine
# Distributes containers uniformly
# Override the DIST array to change the distribution
get_distribution() {
		QUANT=$(( $1/${#ESERVERS[@]} ))
    for ((i = 0; i < ${#ESERVERS[@]}-1; i++)); do
        DIST+=($QUANT)
    done
    REM=$(( $1 - $QUANT*(${#ESERVERS[@]}-1) ))
    DIST+=($REM)
    echo "Container distribution: ${DIST[@]}"
}

stop_all_evm_container() {
    echo "  Removing older evm containers"
    for ((i = 0; i < ${#ESERVERS[@]}; i++)); do
        ((l=l%N)); ((l++==0)) && wait
        ssh ${USERNAME}@${ESERVERS[i]} "
	    docker ps --filter name=levm-* -aq | xargs docker stop | xargs docker rm &> /dev/null
	    " &
	done
    wait
}

# EVM containers will be passed storage node host:port info via env variables
setup_evm_container() {
    echo "Setting up evm"
    mv evm_ips.txt evm_ips.copy
    SNODES=$(<storage_ips.txt)
    SNODES=${SNODES%?}
    echo $SNODES
    stop_all_evm_container
    echo "  Starting evm nodes"
	for ((i = 0; i < ${#ESERVERS[@]}; i++)); do
	    for ((j = 0; j < ${DIST[i]}; j++)); do
            ((l=l%N)); ((l++==0)) && wait
	        ssh ${USERNAME}@${ESERVERS[i]} "
	            docker container rm -f levm-$j &> /dev/null
	            docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} &> /dev/null
	            docker pull ${DOCKER_USER}/rainblock:testVerifStore &> /dev/null
	            docker run -e SNODES=$SNODES --name levm-$j -p $(( PORT+j )):50052 -d ${DOCKER_USER}/rainblock:testVerifStore  &> /dev/null
	        " &
	        echo "${ESERVERS[i]}:$(( PORT+j ))," >> evm_ips.txt
        done
	done
    wait
}

test_container() {
    echo "Testing evm deployment"
	for ((i = 0; i < ${#ESERVERS[@]}; ++i)); do
	    ssh ${USERNAME}@${ESERVERS[i]} "
	        docker container ls
        "
	done
}

setup_docker_deps $1
get_distribution $1
setup_evm_container $1
test_container $1
