#!/bin/bash -eu
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

NEXUS_URL=nexus3.hyperledger.org:10003
ORG_NAME="hyperledger/fabric"
TAG=$GIT_COMMIT
STABLE_TAG=$PUSH_VERSION
export COMMIT_TAG=${TAG:0:7}

echo "----> Publishing PTE image to nexus3..."
echo

cd $WORKSPACE/gopath/src/github.com/hyperledger/fabric-test/

docker build -t $ORG_NAME-pte images/PTE

dockerPTETag() {
  echo "==> $ORG_NAME-pte"
  echo
  docker tag $ORG_NAME-pte $NEXUS_URL/$ORG_NAME-pte:$STABLE_TAG
  docker tag $ORG_NAME-pte $NEXUS_URL/$ORG_NAME-pte:$STABLE_TAG-$COMMIT_TAG
  echo "==> $NEXUS_URL/$ORG_NAME-pte:$STABLE_TAG"
}

dockerPTEPush() {
  echo "==> $ORG_NAME-pte"
  echo
  docker push $NEXUS_URL/$ORG_NAME-pte:$STABLE_TAG
  docker push $NEXUS_URL/$ORG_NAME-pte:$STABLE_TAG-$COMMIT_TAG
  echo
  echo "==> $NEXUS_URL/$ORG_NAME-pte:$STABLE_TAG"
}

# Tag PTE Docker Images to Nexus Repository
echo "----> Tagging PTE image for nexus3 repo..."
echo
dockerPTETag

# Push PTE Docker Images to Nexus Repository
echo "----> Pushing PTE image to nexus3 repo..."
echo
dockerPTEPush

# Listout all docker images Before and After Push to NEXUS
docker images | grep "nexus*"
