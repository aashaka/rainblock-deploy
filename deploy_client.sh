#!/bin/bash
# Usage - ./deploy_client.sh NUM_STORAGE_SERVICES

USERNAME=cc
DOCKER_USER=$(cat config.yaml | shyaml get-value docker_user)
DOCKER_PASS=$(cat config.yaml | shyaml get-value docker_pass)
CSERVERS=($(cat config.yaml | shyaml get-values client_nodes))
DIST=()
N=4
setup_docker_deps() {
  echo "Setting up docker"
	for ((i = 0; i < ${#CSERVERS[@]}; i++)); do
		if [[ "$i" -lt "$1" ]]
		then
			# Setup docker only if docker not already present
			ssh ${USERNAME}@${CSERVERS[i]} '
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
	QUANT=$(( $1/${#CSERVERS[@]} ))
    for ((i = 0; i < ${#CSERVERS[@]}-1; i++)); do
        DIST+=($QUANT)
    done
    REM=$(( $1 - $QUANT*(${#CSERVERS[@]}-1) ))
    DIST+=($REM)
    echo "Container distribution: ${DIST[@]}"
}

stop_all_client_container() {
    echo "  Removing older client containers"
    for ((i = 0; i < ${#CSERVERS[@]}; i++)); do
        ((l=l%N)); ((l++==0)) && wait
        ssh ${USERNAME}@${CSERVERS[i]} "
	    docker ps --filter name=client-* -aq | xargs docker stop | xargs docker rm &> /dev/null
	    " &
	done
    wait
}

# Clients receive info about storage and evm host:port through env variables
setup_client_container() {
    echo "Setting up client"
    mv client_ips.txt client_ips.copy
    SNODES=$(<storage_ips.txt)
    SNODES=${SNODES%?}
    ENODES=$(<evm_ips.txt)
    ENODES=${ENODES%?}
    echo $SNODES
	echo $ENODES
    stop_all_client_container
    echo "  Starting client nodes"
	for ((i = 0; i < ${#CSERVERS[@]}; i++)); do
	    for ((j = 0; j < ${DIST[i]}; j++)); do
            ((l=l%N)); ((l++==0)) && wait
	        ssh ${USERNAME}@${CSERVERS[i]} "
	            docker container rm -f client-$j &> /dev/null
	            docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} &> /dev/null
	            docker pull rainblock/rainblock:testCliStore &> /dev/null
	            docker run -e SNODES=$SNODES -e ENODES=$ENODES --name client-$j -d rainblock/rainblock:testCliStore  &> /dev/null
	        " &
	        echo "${CSERVERS[i]}:$(( PORT+j ))," >> client_ips.txt
        done
	done
    wait
}

test_container() {
    echo "Testing client deployment"
	for ((i = 0; i < ${#CSERVERS[@]}; ++i)); do
	    ssh ${USERNAME}@${CSERVERS[i]} "
	        docker container ls
        "
	done
}

setup_docker_deps $1
get_distribution $1
setup_client_container $1
test_container $1
