#!/bin/bash
# Dependency - shyaml. pip install shyaml.
# Usage - ./deploy_storage.sh NUM_STORAGE_SERVICES

USERNAME=cc
DOCKER_USER=$(cat config.yaml | shyaml get-value docker_user)
DOCKER_PASS=$(cat config.yaml | shyaml get-value docker_pass)
SSERVERS=($(cat config.yaml | shyaml get-values storage_nodes))
echo $SSERVERS
PORT=4000
DIST=()
N=4
setup_docker_deps() {
  echo "Setting up docker"
	for ((i = 0; i < ${#SSERVERS[@]}; i++)); do
		if [[ "$i" -lt "$1" ]]
		then
			# Setup docker only if docker not already present
			ssh ${USERNAME}@${SSERVERS[i]} '
			if [ -x "$(command -v docker)" ]; then
				:
			else
				(curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - ) &> /dev/null
				sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &> /dev/null
				sudo apt-get update &> /dev/null
				sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu &> /dev/null
				sudo usermod -a -G docker $USER &> /dev/null
			fi
			'
		fi
	done
}

# Gives the number of containers in each machine
# Distributes containers uniformly
# Override the DIST array to change the distribution
get_distribution() {
		QUANT=$(( $1/${#SSERVERS[@]} ))
    for ((i = 0; i < ${#SSERVERS[@]}-1; i++)); do
        DIST+=($QUANT)
    done
    REM=$(( $1 - $QUANT*(${#SSERVERS[@]}-1) ))
    DIST+=($REM)
    echo "Container distribution: ${DIST[@]}"
}

stop_all_storage_container() {
    echo "  Removing older storage containers"
    for ((i = 0; i < ${#SSERVERS[@]}; i++)); do
        ((l=l%N)); ((l++==0)) && wait
        ssh ${USERNAME}@${SSERVERS[i]} "
	    docker ps --filter name=sstore-* -aq | xargs docker stop | xargs docker rm &> /dev/null
	    " &
	done
    wait
}

setup_storage_container() {
    echo "Setting up storage"
    mv storage_ips.txt storage_ips.copy
    stop_all_storage_container
    echo "  Starting storage nodes"
	for ((i = 0; i < ${#SSERVERS[@]}; i++)); do
	    for ((j = 0; j < ${DIST[i]}; j++)); do
            ((l=l%N)); ((l++==0)) && wait
	        ssh ${USERNAME}@${SSERVERS[i]} "
	            docker container rm -f sstore-$j &> /dev/null
	            docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} &> /dev/null
	            docker pull ${DOCKER_USER}/rainblock:mainStore &> /dev/null
	            docker run --name sstore-$j -p $(( PORT+j )):50051 -d ${DOCKER_USER}/rainblock:mainStore &> /dev/null
	        " &
	        echo -n "${SSERVERS[i]}:$(( PORT+j ))," >> storage_ips.txt
        done
	done
    wait
}

test_container() {
    echo "Testing storage deployment"
	for ((i = 0; i < ${#SSERVERS[@]}; ++i)); do
	    ssh ${USERNAME}@${SSERVERS[i]} "
	        docker container ls
        "
	done
}

setup_docker_deps $1
get_distribution $1
setup_storage_container $1
test_container $1
