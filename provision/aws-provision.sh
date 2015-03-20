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

EXTERNAL_IP=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
echo using EXTERNAL_IP=$EXTERNAL_IP
echo using AWS_ACCESS_KEY=$1
# AWS_SECRET_KEY is assumed in $2

set +x

echo applying cloudconfig.yaml
sudo coreos-cloudinit -from-file=/home/core/share/cloudconfig.yaml

# continue with the script which is used with both aws and vagrant
source $(dirname "${BASH_SOURCE[0]}")/provision.sh $EXTERNAL_IP $1 $2
