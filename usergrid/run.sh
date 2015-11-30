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
# configuration settings into the container. you set configurable
# options using environment variables.
#
# overwrite any of the following default values at run time like this:
#  docker run --env <key>=<value>

if [ -z "${CLUSTER_NAME}" ]; then
  CLUSTER_NAME='Cassandra Cluster'
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
if [ -z "${JAVA_HOME}" ]; then
  JAVA_HOME=/usr/lib/jvm/java-8-oracle
fi

echo "+++ usergrid configuration:  CLUSTER_NAME=${CLUSTER_NAME}  ADMIN_USER=${ADMIN_USER}  JAVA_HOME=${JAVA_HOME}  ORG_NAME=${ORG_NAME}  APP_NAME=${APP_NAME}  AWS_ACCESS_KEY=${AWS_ACCESS_KEY}"


# start usergrid
# ==============

USERGRID_PROPERTIES_FILE=/var/lib/tomcat7/webapps/ROOT/WEB-INF/classes/usergrid-custom.properties

echo +++ start tomcat for initial deploy of usergrid war
service tomcat7 start

until [ "`curl --silent --show-error --connect-timeout 1 -I http://localhost:8080 | grep 'Coyote'`" != "" ];
do
  echo "+++ waiting for tomcat deployment to finish" && sleep 2
done
while [ ! -f /var/lib/tomcat7/webapps/ROOT/WEB-INF/classes/usergrid-rest-context.xml ] ;
do
  echo "+++ waiting for tomcat deployment to finish" && sleep 2
done

echo +++ move usergrid configuration file to correct location in extracted war file
mv /root/usergrid-default.properties $USERGRID_PROPERTIES_FILE

echo +++ usergrid configuration
sed -i "s/cassandra.url=localhost:9160/cassandra.url=${CASSANDRA_PORT_9160_TCP_ADDR}:${CASSANDRA_PORT_9160_TCP_PORT}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/cassandra.cluster=Test Cluster/cassandra.cluster=$CLUSTER_NAME/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.version.build=\${version}/usergrid.version.build=unknown/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.name=superuser/usergrid.sysadmin.login.name=$ADMIN_USER/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.email=super@usergrid.com/usergrid.sysadmin.login.email=$ADMIN_MAIL/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.password=passwordtest/usergrid.sysadmin.login.password=$ADMIN_PASS/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.test-account/#usergrid.test-account/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#elasticsearch.hosts=127.0.0.1/elasticsearch.hosts=${ELASTICSEARCH_PORT_9300_TCP_ADDR}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/#elasticsearch.port=9300/elasticsearch.port=${ELASTICSEARCH_PORT_9300_TCP_PORT}/g" $USERGRID_PROPERTIES_FILE 

# append java options for aws access key and aws secret key 
# but do not echo the secret so it does not end up in the logs
echo >> /etc/default/tomcat7
set +x
echo "JAVA_OPTS=\"\${JAVA_OPTS} -DAWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY} -DAWS_SECRET_KEY=${AWS_SECRET_KEY}\"" >> /etc/default/tomcat7

echo +++ load changed usergrid configuration
service tomcat7 stop
sleep 1 # give tomcat some time to clean up
service tomcat7 start

# database setup
# ==============

while [ -z "$(curl -s localhost:8080/status | grep '"cassandraAvailable" : true')" ] ;
do
  echo "+++ tomcat log:"
  tail /var/log/tomcat7/catalina.out
  echo "+++ waiting for cassandra being available to usergrid"
  sleep 2
done

echo +++ usergrid database init
curl --user ${ADMIN_USER}:${ADMIN_PASS} http://localhost:8080/system/database/setup

echo +++ usergrid superuser init
curl --user ${ADMIN_USER}:${ADMIN_PASS} http://localhost:8080/system/superuser/setup

echo +++ create organization and corresponding organization admin account
curl -D - \
     -X POST  \
     -d "organization=${ORG_NAME}&username=${ORG_NAME}admin&name=${ORG_NAME}admin&email=${ORG_NAME}admin@example.com&password=${ORG_NAME}admin" \
     http://localhost:8080/management/organizations

echo +++ create admin token with permissions
export ADMINTOKEN=$(curl -X POST --silent "http://localhost:8080/management/token" -d "{ \"username\":\"${ORG_NAME}admin\", \"password\":\"${ORG_NAME}admin\", \"grant_type\":\"password\"} " | cut -f 1 -d , | cut -f 2 -d : | cut -f 2 -d \")
echo ADMINTOKEN=$ADMINTOKEN

echo +++ create app
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -H "Content-Type: application/json" \
     -X POST -d "{ \"name\":\"${APP_NAME}\" }" \
     http://localhost:8080/management/orgs/${ORG_NAME}/apps


echo +++ delete guest permissions
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X DELETE "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/guest"

echo +++ delete default permissions which are too permissive
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X DELETE "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/default" 


echo +++ create new guest role
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles" \
     -d "{ \"name\":\"guest\", \"title\":\"Guest\" }"

echo +++ create new default role, applied to each logged in user
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles" \
     -d "{ \"name\":\"default\", \"title\":\"User\" }"


echo +++ create guest permissions required for login
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

echo +++ create default permissions for a logged in user
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/default/permissions" \
     -d "{ \"permission\":\"get,put,post,delete:/users/\${user}/**\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/roles/default/permissions" \
     -d "{ \"permission\":\"post:/notifications\" }"

echo +++ create user
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORG_NAME}/${APP_NAME}/users" \
     -d "{ \"username\":\"${ORG_NAME}user\", \"password\":\"${ORG_NAME}user\", \"email\":\"${ORG_NAME}user@example.com\" }"

echo
echo +++ done

# log usergrid output do stdout so it shows up in docker logs
less +F /var/log/tomcat7/catalina.out /var/log/tomcat7/localhost_access_log.20*.txt
