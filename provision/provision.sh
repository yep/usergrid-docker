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

echo
echo "+++ provision.sh"

# all parameters to this shell script are optional, defauls will be used otherwise
ORG_NAME=$1
APP_NAME=$2
ADMIN_PASS=$3

echo "+++ stop running docker containers"
docker stop $(docker ps --quiet)

echo -x

echo "+++ remove existing container images"
docker rm -f usergrid cassandra elasticsearch

echo "+++ start containers"
docker run -d --log-driver=syslog --name cassandra -p 9160:9160 -p 9042:9042 --volume /media/data/cassandra-data:/var/lib/cassandra yep1/usergrid-cassandra
docker run -d --log-driver=syslog --name elasticsearch --volume /media/data/elasticsearch-data:/data yep1/usergrid-elasticsearch
docker run -d --log-driver=syslog --name usergrid --env EXTERNAL_IP=${EXTERNAL_IP} --env AWS_ACCESS_KEY=${AWS_ACCESS_KEY} --env AWS_SECRET_KEY=${AWS_SECRET_KEY} --env ADMIN_PASS=${ADMIN_PASS} --env ORG_NAME=${ORG_NAME} --env APP_NAME=${APP_NAME} --link elasticsearch:elasticsearch --link cassandra:cassandra -p 8080:8080 -t yep1/usergrid
