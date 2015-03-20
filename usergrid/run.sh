#!/bin/sh -x

# Copyright 2014 Jahn Bertsch
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
if [ -z "${ORGNAME}" ]; then
  ORGNAME=org
fi
if [ -z "${APPNAME}" ]; then
  APPNAME=app
fi
if [ -z "${EXTERNAL_IP}" ]; then
  # default ip the web interface (admin portal) will use.
  # should be reachable from outside of docker.
  # when using the vagrantfile, this will be updated automatically to the value
  # set in vagrantfile's variable called "ip"
  EXTERNAL_IP=192.168.1.34
fi
if [ -z "${JAVA_HOME}" ]; then
  JAVA_HOME=/usr/lib/jvm/java-8-oracle
fi

echo "usergrid configuration:  CLUSTER_NAME=$CLUSTER_NAME  ADMIN_USER=$ADMIN_USER  ADMIN_PASS  EXTERNAL_IP=$EXTERNAL_IP  JAVA_HOME=$JAVA_HOME  AWS_ACCESS_KEY=$AWS_ACCESS_KEY"


# start usergrid
# ==============

USERGRID_PROPERTIES_FILE=/var/lib/tomcat7/webapps/ROOT/WEB-INF/classes/usergrid-custom.properties

# start tomcat for initial deploy of usergrid war
service tomcat7 start

# wait until tomcat has deployed the usergrid war
until [ "`curl --silent --show-error --connect-timeout 1 -I http://localhost:8080 | grep 'Coyote'`" != "" ];
do
  echo "waiting for tomcat deployment fo finish." && sleep 2
done
while [ ! -f /var/lib/tomcat7/webapps/ROOT/WEB-INF/classes/usergrid-rest-context.xml ] ;
do
  echo "waiting for tomcat deployment fo finish." && sleep 2
done

# copy usergrid configuration file to correct location in extracted war file
cp /root/usergrid/stack/config/src/main/resources/usergrid-default.properties $USERGRID_PROPERTIES_FILE

# usergrid configuration
sed -i "s/cassandra.url=localhost:9160/cassandra.url=${CASSANDRA_PORT_9160_TCP_ADDR}:${CASSANDRA_PORT_9160_TCP_PORT}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/cassandra.cluster=Test Cluster/cassandra.cluster=$CLUSTER_NAME/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.version.build=\${version}/2.0/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.name=/usergrid.sysadmin.login.name=$ADMIN_USER/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.email=/usergrid.sysadmin.login.email=$ADMIN_MAIL/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.password=/usergrid.sysadmin.login.password=$ADMIN_PASS/g" $USERGRID_PROPERTIES_FILE
sed -i "s/usergrid.sysadmin.login.allowed=false/usergrid.sysadmin.login.allowed=true/g" $USERGRID_PROPERTIES_FILE
sed -i "s/localhost:8080/${EXTERNAL_IP}:8080/g" $USERGRID_PROPERTIES_FILE
sed -i "s/elasticsearch.hosts=127.0.0.1/elasticsearch.hosts=${ELASTICSEARCH_PORT_9300_TCP_ADDR}/g" $USERGRID_PROPERTIES_FILE
sed -i "s/elasticsearch.port=9300/elasticsearch.port=${ELASTICSEARCH_PORT_9300_TCP_PORT}/g" $USERGRID_PROPERTIES_FILE 

# make the usergrid portal accessable
chmod 755 /root

# patch usergrid portal url
sed -i "s/Usergrid.overrideUrl = 'http:\/\/localhost:8080\/';/Usergrid.overrideUrl = 'http:\/\/${EXTERNAL_IP}:8080\/';/g" /root/usergrid/portal/config.js

# add portal to default host
sed -i "s/<\/Host>/  <Context docBase=\"\/root\/usergrid\/portal\" path=\"\/portal\" \/>\n      <\/Host>/g" /etc/tomcat7/server.xml

# append java options for aws access key and aws secret key (but do not echo the secret)
echo >> /etc/default/tomcat7
set +x
echo "JAVA_OPTS=\"\${JAVA_OPTS} -DAWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY} -DAWS_SECRET_KEY=${AWS_SECRET_KEY}\"" >> /etc/default/tomcat7
set -x

# load changed usergrid configuration
service tomcat7 stop
sleep 1 # give tomcat some time to clean up
kill $(ps aux | grep 'java' | awk '{print $2}') # if tomcat is still running, kill it
service tomcat7 start


# database setup
# ==============

# wait until cassandra is available
while [ -z "$(curl -s localhost:8080/status | grep '"cassandraAvailable" : true')" ] ;
do
  tail /var/log/tomcat7/catalina.out && echo "waiting for cassandra being available to usergrid." && sleep 2
done

# usergrid database init
curl --user admin:admin http://localhost:8080/system/database/setup

# usergrid superuser init
curl --user admin:admin http://localhost:8080/system/superuser/setup

# create organization and corresponding organization admin account
curl -D - \
     -X POST  \
     -d "organization=${ORGNAME}&username=${ORGNAME}admin&name=${ORGNAME}admin&email=${ORGNAME}admin@example.com&password=${ORGNAME}admin" \
     http://localhost:8080/management/organizations

echo create admin token with permissions for above organization
export ADMINTOKEN=$(curl -X POST --silent "http://localhost:8080/management/token" -d "{ \"username\":\"${ORGNAME}admin\", \"password\":\"${ORGNAME}admin\", \"grant_type\":\"password\"} " | cut -f 1 -d , | cut -f 2 -d : | cut -f 2 -d \")
echo ADMINTOKEN=$ADMINTOKEN

echo create app
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -H "Content-Type: application/json" \
     -X POST -d "{ \"name\":\"${APPNAME}\" }" \
     http://localhost:8080/management/orgs/${ORGNAME}/apps


echo delete guest permissions
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X DELETE "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/guest"

echo delete default permissions which are too permissive
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X DELETE "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/default" 


echo create new guest role
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles" \
     -d "{ \"name\":\"guest\", \"title\":\"Guest\" }"

echo create new default role, applied to each logged in user
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles" \
     -d "{ \"name\":\"default\", \"title\":\"User\" }"


echo create guest permissions required for login
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"post:/token\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"post:/users\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"get:/auth/facebook\" }"

curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/guest/permissions" \
     -d "{ \"permission\":\"get:/auth/googleplus\" }"

echo create default permissions for a logged in user
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/roles/default/permissions" \
     -d "{ \"permission\":\"get,put,post,delete:/users/\${user}/**\" }"


echo create user
curl -D - \
     -H "Authorization: Bearer ${ADMINTOKEN}" \
     -X POST "http://localhost:8080/${ORGNAME}/${APPNAME}/users" \
     -d "{ \"username\":\"${ORGNAME}user\", \"password\":\"${ORGNAME}user\", \"email\":\"${ORGNAME}user@example.com\" }"


# done
# ====

# log usergrid output do stdout so it shows up in docker logs
tail -f /var/log/tomcat7/catalina.out /var/log/tomcat7/localhost_access_log.20*.txt

