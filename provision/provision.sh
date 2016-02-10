#!/bin/bash

# Copyright 2015 TOMORROW FOCUS News+ GmbH
# Copyright 2016 Jahn Bertsch
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

echo "+++ provision.sh"

# all parameters to this shell script are optional, defaults will be used otherwise
USERGRID_HOST=$1
ORG_NAME=$2
APP_NAME=$3
ADMIN_PASS=$4

echo "+++ stop running docker containers"
docker stop $(docker ps --quiet)

echo "+++ remove existing container images"
docker rm -f usergrid cassandra elasticsearch portal

echo "+++ start containers"
docker run -d --log-driver=syslog --name cassandra -p 9160:9160 -p 9042:9042 --volume ./cassandra-data:/var/lib/cassandra yep1/usergrid-cassandra
docker run -d --log-driver=syslog --name elasticsearch --volume ./elasticsearch-data:/data yep1/usergrid-elasticsearch
docker run -d --log-driver=syslog --name usergrid --env ADMIN_PASS=${ADMIN_PASS} --env ORG_NAME=${ORG_NAME} --env APP_NAME=${APP_NAME} --link elasticsearch:elasticsearch --link cassandra:cassandra -p 8080:8080 -t yep1/usergrid
docker run -d --log-driver=syslog --name portal --env USERGRID_HOST=${USERGRID_HOST} -p 80:80 yep1/usergrid-portal
