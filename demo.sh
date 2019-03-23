#!/bin/bash
# This is a demo
USERNAME=$(cat config.yaml | shyaml get-value remote_user)
SSERVERS=($(cat config.yaml | shyaml get-values storage_nodes))
ESERVERS=($(cat config.yaml | shyaml get-values evm_nodes))
CSERVERS=($(cat config.yaml | shyaml get-values client_nodes))

mkdir logs

./deploy.sh 1 1 1

sleep 10

ssh $USERNAME@${SSERVERS[0]} "docker logs sstore-0 &> server.log"
scp $USERNAME@${SSERVERS[0]}:~/server.log logs/server.log

ssh $USERNAME@${ESERVERS[0]} "docker logs levm-0 &> levm.log"
scp $USERNAME@${ESERVERS[0]}:~/levm.log logs/levm.log

ssh $USERNAME@${CSERVERS[0]} "docker logs client-0 &> client.log"
scp $USERNAME@${CSERVERS[0]}:~/client.log logs/client.log