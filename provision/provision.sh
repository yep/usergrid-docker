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

# used by vagrant-provision.sh and aws-provision.sh

echo
echo '+ provision.sh'

EXTERNAL_IP=$1
AWS_ACCESS_KEY=$2
AWS_SECRET_KEY=$3

echo using AWS_ACCESS_KEY=${AWS_ACCESS_KEY}

# stop all running containers
echo stopping running docker containers
docker stop $(docker ps --quiet)

echo -x

# remove existing container instances
docker rm -f usergrid-dev usergrid cassandra elasticsearch

# build dependencies
docker build -t java ./share/java
docker build -t cassandra ./share/cassandra
docker build -t elasticsearch ./share/elasticsearch

# build usergrid development container
docker build -t usergrid-dev ./share/usergrid-dev

# export the deployable tomcat app archive called `ROOT.war` and other files from `usergrid-dev` container
docker run -v $(pwd)/share/usergrid:/root/export -t usergrid-dev /bin/bash -c "\
  cp /root/usergrid/stack/rest/target/ROOT.war /root/export && \
  cp /root/usergrid/stack/config/src/main/resources/usergrid-default.properties /root/export && \
  cp -R /root/usergrid/portal /root/export"

# build usergrid production container using the `ROOT.war` from previous step
docker build -t usergrid ./share/usergrid

echo starting containers
docker run -d --name cassandra -p 9160:9160 cassandra
docker run -d --name elasticsearch elasticsearch
docker run -d --name usergrid --env EXTERNAL_IP=$1 --env AWS_ACCESS_KEY=${AWS_ACCESS_KEY} --env AWS_SECRET_KEY=${AWS_SECRET_KEY} --link elasticsearch:elasticsearch --link cassandra:cassandra -p 8080:8080 -t usergrid

docker logs -f usergrid
