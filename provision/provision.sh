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
ORG_NAME=$4
APP_NAME=$5
ADMIN_PASS=$6
export 

echo using AWS_ACCESS_KEY=${AWS_ACCESS_KEY}

# stop all running containers
echo stopping running docker containers
docker stop $(docker ps --quiet)

echo -x

# remove existing container instances
docker rm -f nm-usergrid-dev nm-usergrid nm-cassandra nm-elasticsearch

# build dependencies
echo; echo build java container
docker build -t nm-java ./share/java

echo; echo build cassandra container
docker build -t nm-cassandra ./share/cassandra

echo; echo build elasticsearch container
docker build -t nm-elasticsearch ./share/elasticsearch

echo; echo build usergrid development container
docker build -t nm-usergrid-dev ./share/usergrid-dev

# export the deployable tomcat app archive called `ROOT.war` and other files from `nm-usergrid-dev` container
docker run -v $(pwd)/share/usergrid:/root/export -t nm-usergrid-dev /bin/bash -c "\
  cp /root/usergrid/stack/rest/target/ROOT.war /root/export && \
  cp /root/usergrid/stack/config/src/main/resources/usergrid-default.properties /root/export && \
  cp -R /root/usergrid/portal /root/export"

# use the deployable tomcat app archive from previous step to build usergrid container
echo; echo build usergrid production container
docker build -t nm-usergrid ./share/usergrid

echo starting containers
docker run -d --log-driver=syslog --name nm-cassandra -p 9160:9160 -p 9042:9042 --volume /media/data/cassandra-data:/var/lib/cassandra nm-cassandra
docker run -d --log-driver=syslog --name nm-elasticsearch --volume /media/data/elasticsearch-data:/data nm-elasticsearch
docker run -d --log-driver=syslog --name nm-usergrid --env EXTERNAL_IP=${EXTERNAL_IP} --env AWS_ACCESS_KEY=${AWS_ACCESS_KEY} --env AWS_SECRET_KEY=${AWS_SECRET_KEY} --env ADMIN_PASS=${ADMIN_PASS} --env ORGNAME=${ORG_NAME} --env APPNAME=${APP_NAME} --link nm-elasticsearch:nm-elasticsearch --link nm-cassandra:nm-cassandra -p 8080:8080 -p 8443:8443 -t nm-usergrid
