#!/bin/bash
# Usage - ./deploy_storage.sh

USERNAME=$(cat config.yaml | shyaml get-value remote_user)
DOCKER_USER=$(cat config.yaml | shyaml get-value docker_user)
DOCKER_PASS=$(cat config.yaml | shyaml get-value docker_pass)

SSERVERS=()
NSERVERS=()
for ((i=0; i<16; i++)); do
  SSERVERS[i]=$(cat config.yaml | shyaml get-values storage_nodes.$i.ips)
  NSERVERS[i]=$(cat config.yaml | shyaml get-value storage_nodes.$i.number)
done

PORT=4000
DIST=()
N=4

get_unique_snodes(){
  declare -A items=()
  for ((i=0; i<16; i++)); do
    for item in ${SSERVERS[i]}; do
        items[$item]=1
    done
  done
  SUNIQUE=(${!items[*]})
  echo "SUNIQUE is "
  echo ${SUNIQUE[@]}
}

setup_deps() {
  echo "--- Setting up dependencies"

  # Setup docker
  for ((i = 0; i < ${#SUNIQUE[@]}; i++)); do
    # Setup docker only if docker not already present
    ssh ${USERNAME}@${SUNIQUE[i]} '
    if [ -x "$(command -v docker)" ]; then
      :
    else
      (curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - ) &> /dev/null
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" &> /dev/null
      sudo apt-get update &> /dev/null
      sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu &> /dev/null
      sudo usermod -a -G docker $USER &> /dev/null
    fi
    ' &
  done
  wait

  # Login and pull storage image
  for ((i = 0; i < ${#SUNIQUE[@]}; i++)); do
    ssh ${USERNAME}@${SUNIQUE[i]} "
      docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} &> /dev/null
      docker pull ${DOCKER_USER}/rainblock:mainStore &> /dev/null
    " &
  done
  wait

}

# Gives the number of containers in each machine
# Distributes containers uniformly
# Override the DIST array to change the distribution
get_distribution() {
  for ((i=0; i<16; i++)); do
    NUM=(${SSERVERS[i]})
    QUANT=$(( ${NSERVERS[i]}/${#NUM[@]} ))
    for ((j = 0; j < ${#NUM[@]}-1; j++)); do
        DIST[i]+=$QUANT
        DIST[i]+=" "
    done
    REM=$(( ${NSERVERS[i]} - $QUANT*(${#NUM[@]}-1) ))
    DIST[i]+=$REM
    # echo "Container distribution for $i: ${DIST[i]} "
  done
}

stop_all_storage_container() {
    echo "--- Removing older storage containers"
  for ((i = 0; i < ${#SUNIQUE[@]}; i++)); do
    ssh ${USERNAME}@${SUNIQUE[i]} "
      docker ps --filter name=sstore$k-* -aq | xargs docker stop | xargs docker rm &> /dev/null
      " &
  done
}

setup_storage_container() {
    mv storage_ips.txt storage_ips.copy
    stop_all_storage_container
    echo "--- Starting storage nodes"
    echo "storage:" >> storage_ips.txt
  for ((k = 0; k < 16; k++)); do
    echo -e "\t$k:" >> storage_ips.txt
    SARRAY=(${SSERVERS[k]})
    DISTARRAY=(${DIST[k]})
    for ((i = 0; i < ${#SARRAY[@]}; i++)); do
      for ((j = 0; j < ${DISTARRAY[i]}; j++)); do
            ((l=l%N)); ((l++==0)) && wait
          ssh ${USERNAME}@${SARRAY[i]} "
              docker run --name sstore$k-$j -p $(( PORT+k*100+j )):50051 -d ${DOCKER_USER}/rainblock:mainStore node -r ts-node/register src/server.ts $k 50051 &> /dev/null
          " &
          echo -e "\t\t- '${SARRAY[i]}:$(( PORT+100*k+j ))'" >> storage_ips.txt
        done
    done
    wait
  done
}

test_container() {
  # Testing storage deployment
  for ((i = 0; i < ${#SUNIQUE[@]}; i++)); do
    ssh ${USERNAME}@${SUNIQUE[i]} '
      docker container ls
    ' &
  done
}

finish_storage_config() {
  echo -e "rpc:\n\tstorageTimeout: 5000\nbeneficiary: 'ea674fdde714fd979de3edf0f56aa9716b898ec8'\ngenesisBlock: 'genesis.bin'" >> storage_ips.txt
}

get_unique_snodes
setup_deps
get_distribution
setup_storage_container
test_container
finish_storage_config