#!/bin/bash

# Copyright 2015 TOMORROW FOCUS News+ GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# use this script to deploy to a core os machine on amazon aws

echo '+ aws-deploy.sh'

# check for missing aws credentials: script could still possibly run, but aws sqs operations will fail
if [ -z "${AWS_ACCESS_KEY}" ]; then
  echo error: AWS_ACCESS_KEY not set!
  exit
fi
if [ -z "${AWS_SECRET_KEY}" ]; then
  echo error: AWS_SECRET_KEY not set!
  exit
fi

set -x

# cd into the directory this script is stored in
cd $(dirname "${BASH_SOURCE[0]}")

# please define this alias in your ssh config
SSH_ALIAS=aws

# where to copy files - destination folder has to be named `share`
FILE_LOCATION=/home/core/share

DESTINATION=$SSH_ALIAS:$FILE_LOCATION

# remove old files
ssh -v -o StrictHostKeyChecking=no $SSH_ALIAS "sudo rm -rf $FILE_LOCATION; mkdir -p $FILE_LOCATION"

# copy files to aws machine
scp aws-provision.sh provision.sh cloudconfig.yaml $DESTINATION
scp -r ../java ../usergrid-dev ../usergrid ../cassandra ../elasticsearch $DESTINATION

echo applying cloudconfig.yaml
coreos-cloudinit -from-file=/home/core/share/cloudconfig.yaml

set +x

echo running aws-provision.sh using ssh
ssh $SSH_ALIAS "/bin/bash $FILE_LOCATION/aws-provision.sh ${AWS_ACCESS_KEY} ${AWS_SECRET_KEY}"
