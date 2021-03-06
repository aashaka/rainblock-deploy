## Dependencies
`docker`

shyaml: `pip install shyaml`

## Demo
This demo will run three docker containers containing an instance each of the storage server, test client, and test verifier respectively. It will cause interactions between the three components, and the results of these interactions will be logged. 

`config.yaml` currently looks like this:
```
docker_user: rainblock
docker_pass: some_random_password
remote_user: cc 
storage_nodes:
  - 129.114.108.84 
evm_nodes:
  - 129.114.108.84 
client_nodes:
  - 129.114.108.84 
```

1. Edit config.yaml
	- Replace `remote_user` to user of a machine you are able to ssh into
	- Replace IPs of `storage_nodes`, `evm_nodes`, and `client_nodes` with IPs of the machine you are able to ssh into. They can all be the same IP address.
	- You do not need to edit `docker_user` or `docker_pass`. This docker ID is associated with our images.
2. Run `./deploy.sh 1 1 1`
3. View logs in `logs/`. The expected logs already present in `logs_expected/`. For example, the server log should contain
```
Received shard and port:  -1 50051
grpc server running on at 0.0.0.0:50051
Received Update call
Received Update call
Received Update call
Received Update call
Received Update call
ERROR: update
 Error: Attempt to update a non-existent value
    at StorageNode.update (/home/node/rainblock-storage/src/index.ts:290:17)
    at Object.update (/home/node/rainblock-storage/src/server.ts:281:17)
    at /home/node/rainblock-storage/node_modules/grpc/src/server.js:590:13
Received getBlockHash call
Received getBlockHash call
Received getStorage call
Received getStorage call
Received getAccount call
Received getAccount call
Received getCodeInfo Call
Received getCodeInfo Call
Received getCodeInfo Call
Received getCodeInfo Call
```
The error is expected: we are trying to update a non-existent value.

## Experiments
### Config
Setup configs in config.yaml. See config.yaml.example file for how to set it up. Docker username and password is required to push to a docker repo and pull from a private docker repo.

### Creating Docker images
`./bootstrap/create_fresh_images.sh` generates following images and pushes them to dockerhub:
1. rainblock/rainblock:mainStore - storage node image
2. rainblock/rainblock:testVerifStore - test verifier which simply interacts with storage nodes
3. rainblock/rainblock:testCliStore - test client which simply interacts with storage nodes

### Deploying Docker containers
* `./deploy.sh storage_node.sh num_storage num_evm num_client` will deploy entire system. It is made up of following commands explained below:

* Run `deploy_storage.sh num_storage_containers` to get storage nodes started on storage_nodes IPs specified in config.yaml.

	- The storage container ports are assumed to be 50051. They are mapped to ports starting from 4000 in each machine the containers are deployed in.
	- Number of storage containers will be evenly distributed between storage IPs provided in config.yaml
	- It is assumed that the containers will run on Chameleon Cloud. Change `USERNAME` field from `cc` to match your username on remote host
	- All storage `IP:port` will be written to `storage_ips.txt` in a comma newline separated format after `deploy_storage.sh`

* Run `deploy_evm.sh num_evm_containers` to get evm nodes started on evm_nodes IPs specified in config.yaml. Right now, evm is test_verif_store instance.

	- The storage IP and port that evm should connect to are sent as the environment variable $SNODES. SNODES is the content of `storage_ips.txt`.
	- The actual EVM container will keep ports open for clients to connect to. This port is assumed to be 50052. They are mapped to ports starting from 6000 in each machine the containers are deployed in.
	- Number of evm containers will be evenly distributed between evm IPs provided in config.yaml
	- It is assumed that the containers will run on Chameleon Cloud. Change `USERNAME` field from `cc` to match your username on remote host
	- EVM IP:port will be written to `evm_ips.txt` in a comma newline separated format after `deploy_evm.sh`

* Run `deploy_client.sh num_client_containers` to get client nodes started on client_nodes IPs specified in config.yaml. Right now, client is test_client_store instance.

	- The storage IP and port & EVM IP and port that client should connect to are sent as the environment variable $SNODES and $ENODES. SNODES and ENODES are the content of `storage_ips.txt` and `evm_ips.txt`
	- Number of client containers will be evenly distributed between client IPs provided in config.yaml
	- It is assumed that the containers will run on Chameleon Cloud. Change `USERNAME` field from `cc` to match your username on remote host


### Note
- For dockerizing, testVerifier.ts and testClient.ts in rainblock-storage needs extra environment variable handling to get storage nodes IP:port. We use a separate branch `dockertest` on rainblock-storage for this. We create docker containers from this branch.
- Downloading a zip file directly from github/gitlab repo and making docker image based on it will fail. This is because it will not have a .git folder, which is required for gitmodules to initialize. Instead, clone the repo, zip it and send it over to docker image.
