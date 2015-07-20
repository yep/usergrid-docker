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

# this script is run on a core os machine on amazon aws

echo
echo '+ aws-provision.sh'

if [ -z "$1" ]; then
  echo 'Error: AWS_ACCESS_KEY not set!'
  exit
fi
if [ -z "$2" ]; then
  echo 'Error: AWS_SECRET_KEY not set!'
  exit
fi
if [ -z "$3" ]; then
  echo 'Warning: ORG_NAME not set! Using "org"'
  ORG_NAME=org
else
  ORG_NAME=$3
fi
if [ -z "$4" ]; then
  echo 'Warning: APP_NAME not set! Using "app"'
  APP_NAME=app
else
  APP_NAME=$4
fi
if [ -z "$5" ]; then
  echo 'Info: ADMIN_PASSWORD not set!'
fi

EXTERNAL_IP=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
echo using EXTERNAL_IP=$EXTERNAL_IP
echo using AWS_ACCESS_KEY=$1
# AWS_SECRET_KEY is assumed in $2

set +x

echo apply cloudconfig.yaml
sudo mkdir -p /var/lib/coreos-install
sudo mv /home/core/share/cloudconfig.yaml /var/lib/coreos-install/user_data
sudo coreos-cloudinit -from-file=/var/lib/coreos-install/user_data

# continue with the script which is used with both aws and vagrant
source $(dirname "${BASH_SOURCE[0]}")/provision.sh $EXTERNAL_IP $1 $2 $ORG_NAME $APP_NAME $5
