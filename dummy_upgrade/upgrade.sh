#!/bin/bash

set -e

echo "====="
echo "Fetching engine binaries"
echo "====="
curl "https://raw.githubusercontent.com/ctelfer/moby-lb-upgrade-test/master/dummy_upgrade/engine-binaries.tgz" > /tmp/new-engine-binaries.tgz
echo "====="
echo "Stopping Docker service"
echo "====="
sudo service docker stop 
echo "====="
echo "Saving engine binaries in /tmp/old-engine-binaries.tgz"
echo "====="
cd /usr/bin/
sudo tar zcvf /home/docker/old-engine-binaries.tgz docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-init docker-proxy docker-runc
echo "====="
echo "Removing old binaries"
echo "====="
sudo rm docker-containerd docker-containerd-ctr docker-containerd-shim dockerd docker-init docker-proxy docker-runc
echo "====="
echo "Installing new binaries"
echo "====="
sudo tar zxvf /tmp/new-engine-binaries.tgz
echo "====="
echo "Restarting docker service"
echo "====="
sudo service docker start
echo "====="
echo "Complete ... old and new binaries are still in /tmp/(old|new)-engine-binaries.tgz"
echo "====="
docker version
