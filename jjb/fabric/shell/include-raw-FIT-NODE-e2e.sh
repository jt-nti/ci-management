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

WD="${WORKSPACE}/gopath/src/github.com/hyperledger/fabric-sdk-node"
SDK_REPO_NAME=fabric-sdk-node
git clone git://cloud.hyperledger.org/mirror/$SDK_REPO_NAME $WD
cd $WD
git checkout $GERRIT_BRANCH

# error check
err_check() {
echo "--------> $1 <---------"
exit 1
}

SDK_NODE_COMMIT=$(git log -1 --pretty=format:"%h")
echo "------> SDK_NODE_COMMIT : $SDK_NODE_COMMIT"
echo "SDK_NODE_COMMIT=======> $SDK_NODE_COMMIT" >> ${WORKSPACE}/gopath/src/github.com/hyperledger/commit.log

cd test/fixtures
docker rm -f "$(docker ps -aq)" || true
docker-compose up >> node_dockerlogfile.log 2>&1 &
sleep 10
docker ps -a
cd ../..

# Install nvm to install multi node versions
wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
# shellcheck source=/dev/null
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

echo "-------> Install NodeJS"

# Checkout to GERRIT_BRANCH
if [[ "$GERRIT_BRANCH" = *"release-1.0"* ]]; then # Only on release-1.0 branch
    NODE_VER=6.9.5
    echo "------> Use $NODE_VER for release-1.0 branch"
    nvm install $NODE_VER
    # use nodejs 6.9.5 version
    nvm use --delete-prefix v$NODE_VER --silent
elif [[ "$GERRIT_BRANCH" = *"release-1.1"* || "$GERRIT_BRANCH" = *"release-1.2"* ]]; then # only on release-1.2 or release-1.1 branches
    NODE_VER=8.9.4
    echo "------> Use $NODE_VER for release-1.1 and release-1.2 branches"
    nvm install $NODE_VER
    # use nodejs 8.9.4 version
    nvm use --delete-prefix v$NODE_VER --silent
 else
    if [[ "$GERRIT_BRANCH" = "master" ]]; then
      NODE_VER=8.11.3
      echo "------> Use $NODE_VER"
      INSTL_VER=$(node -v)
      echo "====> $INSTL_VER"

      if [[ $INSTL_VER = "$NODE_VER" ]]; then
         echo "====> NODE $NODE_VER is installed already"
      else
         nvm install $NODE_VER
         # use nodejs 8.11.3 version
         nvm use --delete-prefix v$NODE_VER --silent
      fi

    else
      NODE_VER=8.11.3
      nvm install $NODE_VER
      # use nodejs 8.11.3 version
      nvm use --delete-prefix v$NODE_VER --silent
    fi
fi

echo "npm version ======>"
npm -v
echo "node version =======>"
node -v

npm install || err_check "npm install failed"
npm config set prefix ~/npm || exit 1
npm install -g gulp || exit 1
npm install -g istanbul || exit 1

gulp || err_check "gulp failed"
gulp ca || err_check "gulp ca failed"

rm -rf node_modules/fabric-ca-client && npm install || err_check "npm install failed"

# Execute e2e tests and code coverage report

echo "#######################################"
echo "Run e2e tests and Code coverage report"
echo "#######################################"

istanbul cover --report cobertura test/integration/e2e.js

function clearContainers () {
    CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" ] || [ "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS || true
                echo "---- Docker containers after cleanup ----"
                docker ps -a
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" ] || [ "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS || true
                echo "---- Docker images after cleanup ----"
                docker images
        fi
}

cd $WD
# remove tmp/hfc and hfc-key-store data
rm -rf node_modules package-lock.json || true
clearContainers
removeUnwantedImages
