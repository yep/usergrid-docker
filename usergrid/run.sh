#!/bin/bash

# Copyright 2014-2015 Jahn Bertsch
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

# this script is invoked after starting up the docker container.
# it allows for configuration at run time instead of baking all
# configuration settings into the container. you can set all configurable
# options using environment variables.
#
# overwrite any of the following default values at run-time like this:
#  docker run --env <key>=<value>

if [ -z "${CASSANDRA_CLUSTER_NAME}" ]; then
  CASSANDRA_CLUSTER_NAME='usergrid'
fi
if [ -z "${USERGRID_CLUSTER_NAME}" ]; then
  USERGRID_CLUSTER_NAME='usergrid'
fi
if [ -z "${ADMIN_USER}" ]; then
  ADMIN_USER=admin
fi
if [ -z "${ADMIN_PASS}" ]; then
  ADMIN_PASS=admin
fi
if [ -z "${ADMIN_MAIL}" ]; then
  ADMIN_MAIL=admin@example.com
fi
if [ -z "${ORG_NAME}" ]; then
  ORG_NAME=org
fi
if [ -z "${APP_NAME}" ]; then
  APP_NAME=app
fi
if [ -z "${TOMCAT_RAM}" ]; then
  TOMCAT_RAM=512m
fi

echo "+++ usergrid configuration:  CASSANDRA_CLUSTER_NAME=${CASSANDRA_CLUSTER_NAME}  USERGRID_CLUSTER_NAME=${USERGRID_CLUSTER_NAME}  ADMIN_USER=${ADMIN_USER}  ORG_NAME=${ORG_NAME}  TOMCAT_RAM=${TOMCAT_RAM}  APP_NAME=${APP_NAME}  AWS_ACCESS_KEY=${AWS_ACCESS_KEY}"


# start usergrid
# ==============

echo "+++ configure usergrid"

USERGRID_PROPERTIES_FILE=/usr/share/tomcat7/lib/usergrid-deployment.properties

sed -i "s/cassandra.url=localhost:9160/cassandra.url=${CASSANDRA_PORT_9160_TCP_ADDR}:${CASSANDRA_PORT_9160_TCP_PORT}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/cassandra.cluster=Test Cluster/cassandra.cluster=$CASSANDRA_CLUSTER_NAME/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#usergrid.cluster_name=default-property/usergrid.cluster_name=$USERGRID_CLUSTER_NAME/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.version.build=\${version}/usergrid.version.build=unknown/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.name=superuser/usergrid.sysadmin.login.name=$ADMIN_USER/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.email=super@usergrid.com/usergrid.sysadmin.login.email=$ADMIN_MAIL/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.password=test/usergrid.sysadmin.login.password=$ADMIN_PASS/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.test-account/#usergrid.test-account/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#elasticsearch.hosts=127.0.0.1/elasticsearch.hosts=${ELASTICSEARCH_PORT_9300_TCP_ADDR}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#elasticsearch.port=9300/elasticsearch.port=${ELASTICSEARCH_PORT_9300_TCP_PORT}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#usergrid.use.default.queue=false/usergrid.use.default.queue=true/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#elasticsearch.queue_impl=LOCAL/elasticsearch.queue_impl=LOCAL/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#cassandra.version=1.2/cassandra.version=2.1/g" $USERGRID_PROPERTIES_FILE

# update tomcat's java options
sed -i "s#\"-Djava.awt.headless=true -Xmx128m -XX:+UseConcMarkSweepGC\"#\"-Djava.awt.headless=true -XX:+UseConcMarkSweepGC -Xmx${TOMCAT_RAM} -Xms${TOMCAT_RAM} -verbose:gc\"#g" /etc/default/tomcat7

echo "+++ start usergrid"
service tomcat7 start


# database setup
# ==============

while [ -z "$(curl -s localhost:8080/status | grep '"cassandraAvailable" : true')" ] ;
do
  echo "+++ tomcat log:"
  tail -n 20 /var/log/tomcat7/catalina.out
  echo "+++ waiting for cassandra being available to usergrid"
  sleep 2
done

echo "+++ usergrid database setup"
curl --user ${ADMIN_USER}:${ADMIN_PASS} -X PUT http://localhost:8080/system/database/setup

echo "+++ usergrid database bootstrap"
curl --user ${ADMIN_USER}:${ADMIN_PASS} -X PUT http://localhost:8080/system/database/bootstrap

echo "+++ usergrid superuser setup"
curl --user ${ADMIN_USER}:${ADMIN_PASS} -X GET http://localhost:8080/system/superuser/setup

echo "+++ create organization and corresponding organization admin account"
curl -D - \
     -X POST  \
     -d "organization=${ORG_NAME}&username=${ORG_NAME}admin&name=${ORG_NAME}admin&email=${ORG_NAME}admin@example.com&password=${ORG_NAME}admin" \
     http://localhost:8080/management/organizations

echo "+++ create admin token with permissions"
export ADMINTOKEN=$(curl -X POST --silent "http://localhost:8080/management/token" -d "{ \"username\":\"${ORG_NAME}admin\", \"password\":\"${ORG_NAME}admin\", \"grant_type\":\"password\"} " | cut -f 1 -d , | cut -f 2 -d : | cut -f 2 -d \")
echo ADMINTOKEN=$ADMINTOKEN

echo "+++ create app"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -H "Content-Type: application/json" \
     -X POST -d "{ \"name\":\"${APP_NAME}\" }" \
     http://localhost:8080/management/orgs/${ORG_NAME}/apps


echo "+++ delete guest permissions"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X DELETE "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/guest"

echo "+++ delete default permissions which are too permissive"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X DELETE "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/default" 


echo "+++ create new guest role"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles" \
     -d "{ \"name\":\"guest\", \"title\":\"Guest\" }"

echo "+++ create new default role, applied to each logged in user"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles" \
     -d "{ \"name\":\"default\", \"title\":\"User\" }"


echo "+++ create guest permissions required for login"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"post:/token\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"post:/users\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"get:/auth/facebook\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"get:/auth/googleplus\" }"

echo "+++ create default permissions for a logged in user"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/default/permissions" \
     -d "{ \"permission\":\"get,put,post,delete:/users/\${user}/**\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/default/permissions" \
     -d "{ \"permission\":\"post:/notifications\" }"

echo "+++ create user"
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/users" \
     -d "{ \"username\":\"${ORG_NAME}user\", \"password\":\"${ORG_NAME}user\", \"email\":\"${ORG_NAME}user@example.com\" }"

echo
echo "+++ done"

# log usergrid output do stdout so it shows up in docker logs
less +F /var/log/tomcat7/catalina.out /var/log/tomcat7/localhost_access_log.20*.txt
