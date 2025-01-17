#!/bin/bash -e
#
# SPDX-License-Identifier: Apache-2.0
##############################################################################
# Copyright (c) 2018 IBM Corporation, The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License 2.0
# which accompanies this distribution, and is available at
# https://www.apache.org/licenses/LICENSE-2.0
##############################################################################
set -o pipefail

# RUN END-to-END Test
#####################
rm -rf ${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-sdk-node

sdk_node_wd="${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-sdk-node"
sdk_repo_name=fabric-sdk-node
git clone git://cloud.hyperledger.org/mirror/$sdk_repo_name $sdk_node_wd
cd $sdk_node_wd
git checkout $GERRIT_BRANCH

container_list=(orderer peer0.org1 peer0.org2 ca0 ca1)
# error check
err_check() {
    echo -e "\033[31m $1" "\033[0m"
    for CONTAINER in ${container_list[*]}; do
      docker logs $CONTAINER.example.com >& $CONTAINER.log || true
    done
    docker logs couchdb >& couchdb.log
    grep /w/workspace/fabric-end-2-end-daily-master-x86_64/gopath/src/github.com/hyperledger/fabric-sdk-node/test/temp/debug.log >& debug.log
    exit 1
}

sdk_node_commit=$(git log -1 --pretty=format:"%h")
echo "------> sdk_node_commit : $sdk_node_commit"
echo "sdk_node_commit=======> $sdk_node_commit" >> ${WORKSPACE}/gopath/src/github.com/hyperledger/commit.log

arch=$(dpkg --print-architecture)
echo "======> ARCH" $arch
set +e
if [[ "$arch" = "amd64" ]]; then
   # Install nvm to install multi node versions
   wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
   export NVM_DIR=$HOME/.nvm
   # shellcheck source=/dev/null
   source $NVM_DIR/nvm.sh # Setup environment for running nvm
else
   source /etc/profile.d/nvmrc.sh
fi
set -e
echo -e "\033[1m----------> SDK-NODE TESTS\033[0m"
echo "-------> Install NodeJS"

wd="${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-chaincode-node"
# Checkout to GERRIT_BRANCH
case $GERRIT_BRANCH in
master)
  echo -e "\033[32m Build Chaincode-nodeenv-image" "\033[0m"
  rm -rf $wd
  repo_name=fabric-chaincode-node
  git clone git://cloud.hyperledger.org/mirror/$repo_name $wd
  cd $wd || exit
  node_ver=10.15.3
  echo "------> Use $node_ver for $GERRIT_BRANCH"
  nvm install $node_ver # use nodejs 10.15.3 version
  nvm use --delete-prefix v$node_ver --silent
  npm install || err_check "npm install failed"
  npm config set prefix ~/npm || exit 1
  echo -e "\033[32m npm version" "\033[0m"
  npm -v
  echo -e "\033[32m node version" "\033[0m"
  node -v
  npm install -g gulp || exit 1
  gulp docker-image-build # Build nodeenv image
  docker images | grep hyperledger && docker ps -a
;;
release-1.4|release-1.3)
  echo "------> Use $node_ver for $GERRIT_BRANCH"
  node_ver=8.11.3
  nvm install $node_ver # use nodejs 8.11.3 version
  nvm use --delete-prefix v$node_ver --silent
  echo -e "\033[32m npm version" "\033[0m"
  npm -v
  echo -e "\033[32m node version" "\033[0m"
  node -v
;;
release-1.2|release-1.1)
  node_ver=8.9.4
  echo "------> Use $node_ver for $GERRIT_BRANCH"
  nvm install $node_ver # use nodejs 8.9.4 version
  nvm use --delete-prefix v$node_ver --silent
  echo -e "\033[32m npm version" "\033[0m"
  npm -v
  echo -e "\033[32m node version" "\033[0m"
  node -v
;;
*)
  node_ver=6.9.5
  echo "------> Use $node_ver for release-1.0 branch"
  nvm install $node_ver # use nodejs 6.9.5 version
  nvm use --delete-prefix v$node_ver --silent
  echo -e "\033[32m npm version" "\033[0m"
  npm -v
  echo -e "\033[32m node version" "\033[0m"
  node -v
;;
esac

cd $sdk_node_wd
npm install || err_check "npm install failed"
npm config set prefix ~/npm || exit 1
npm install -g gulp || exit 1

generatecerts () {
# Generate crypto material before running the tests
if [[ $arch == "s390x" ]]; then
# Run the s390x gulp task
    gulp install-and-generate-certs-s390 || err_check "ERROR!!! gulp install and generation of test certificates failed"
else
# Run the amd64 gulp task
    gulp install-and-generate-certs || err_check "ERROR!!! gulp install and generation of test certificates failed"
fi
}

echo "#################"
echo " Run gulp tests"
echo "#################"

case $GERRIT_BRANCH in
release-1.0|release-1.1|release-1.2|release-1.3)
gulp || err_Check "ERROR!!! gulp failed"
gulp ca || err_Check "ERROR!!! gulp ca failed"
echo "------> Run node Headless & Integration tests"
gulp test || err_Check "ERROR!!! gulp test failed"
;;
release-1.4)
echo "------> Starting gulp end-to-end tests"
gulp run-end-to-end || err_check "ERROR!!! gulp end-2-end tests failed"
;;
*)
generatecerts
echo "------> Starting gulp end-to-end tests"
gulp run-test-merge || err_check "ERROR!!! gulp end-2-end tests failed"
;;
esac

function clearContainers () {
    CONTAINER_IDS=$(docker ps -aq)
        if [[ -z "$CONTAINER_IDS" || "$CONTAINER_IDS" = " " ]]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS || true
                echo "---- Docker containers after cleanup ----"
                docker ps -a
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [[ -z "$DOCKER_IMAGE_IDS" || "$DOCKER_IMAGE_IDS" = " " ]]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS || true
                echo "---- Docker images after cleanup ----"
                docker images
        fi
}
clearContainers
removeUnwantedImages

# remove tmp/hfc and hfc-key-store data
if [[ "$GERRIT_BRANCH" = "master" ]]; then
    cd $wd
    rm -rf node_modules package-lock.json
fi
