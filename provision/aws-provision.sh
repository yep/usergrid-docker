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

# use this script to provision to a core os machine on amazon aws
# if set, the following environment variables will be passed to the aws machine:
#  ORG_NAME
#  APP_NAME
#  ADMIN_PASS

set -x

# where to copy files - destination folder has to be named `share`
FILE_LOCATION=/home/core/share
DESTINATION=${SSH_ALIAS}:${FILE_LOCATION}

echo "+++ remove old files on aws machine (if any)"
ssh -v -o StrictHostKeyChecking=no ${SSH_ALIAS} "sudo rm -rf ${FILE_LOCATION}; mkdir -p ${FILE_LOCATION}"

echo "+++ copy files to aws machine"
scp provision.sh cloudconfig.yaml ${DESTINATION}
scp -r ../java ../usergrid ../cassandra ../elasticsearch ${DESTINATION}

set +x

echo "+++ apply cloudconfig.yaml"
ssh ${SSH_ALIAS} "\
  sudo mkdir -p /var/lib/coreos-install && \
  sudo mv /home/core/share/cloudconfig.yaml /var/lib/coreos-install/user_data && \
  sudo coreos-cloudinit -from-file=/var/lib/coreos-install/user_data"

echo "+++ run provision.sh on aws machine"
PUBLIC_AWS_IP=$(ssh ${SSH_ALIAS} "curl http://169.254.169.254/latest/meta-data/public-ipv4")
ssh ${SSH_ALIAS} "/bin/bash ${FILE_LOCATION}/provision.sh ${PUBLIC_AWS_IP}:8080 ${ORG_NAME} ${APP_NAME} ${ADMIN_PASS}
