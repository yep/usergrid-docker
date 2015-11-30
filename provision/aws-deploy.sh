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

# use this script to deploy to a core os machine on amazon aws

echo '+ aws-deploy.sh'

usage() {
  echo
  echo "Usage: $0 ssh-alias [--push-provider] [--org] [--app] [--admin-password]"
  echo 'Options:'
  echo ' --push-provider google [push-provider name] [api-key]'
  echo ' --push-provider apple [push-provider name] [environment] [certificate] [certificate password]'
  echo ' --org [org name]'
  echo ' --app [app name]'
  echo ' --admin-password [password]'
  exit
}

# helper method to mask passwords for other shell commands
escape() {
  echo "$@"|sed \
    -e 's/\\/\\\\/g' \
    -e "s/'/\\\\'/g" \
    -e 's/"/\\"/g'
}

# check for missing aws credentials: script could still possibly run, but aws sqs operations will fail
if [ -z "${AWS_ACCESS_KEY}" ]; then
  echo error: AWS_ACCESS_KEY not set!
  usage
fi
if [ -z "${AWS_SECRET_KEY}" ]; then
  echo error: AWS_SECRET_KEY not set!
  usage
fi
if [ -z "$1" ]; then
  echo error: ssh-alias missing!
  echo please pass a ssh-alias as first parameter, e.g. "$0 aws"
  usage
fi

# please define this alias in your ssh config
SSH_ALIAS=$1
shift

SCRIPT_HOME=$(dirname "${BASH_SOURCE[0]}")

EXTERNAL_IP=$(ssh $SSH_ALIAS curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# building the post setup script in three steps
# step one: the "static" part which won't change by unparsed arguments
# step two: write the "dynamic" part in a second file
# step three: merge the files and execute it
echo "#/bin/bash" > $SCRIPT_HOME/post_setup.sh
#echo "EXTERNAL_IP='${EXTERNAL_IP}'" >> $SCRIPT_HOME/post_setup.sh
echo "BASE_URL=http://localhost:8080" >> $SCRIPT_HOME/post_setup.sh
echo "# Get the Admin Token">>$SCRIPT_HOME/post_setup2.sh
echo 'ADMIN_TOKEN=$(curl -X POST -s "${BASE_URL}/management/token" -d "{ \"username\":\"${ORG_NAME}admin\", \"password\":\"${ORG_NAME}admin\", \"grant_type\":\"password\"} " | cut -f 1 -d , | cut -f 2 -d : | cut -f 2 -d \")'>>$SCRIPT_HOME/post_setup2.sh

# setting default values
APP_NAME=app
ORG_NAME=org
ADMIN_PASS=admin

# parse other arguments
while [ $# -gt 0 ] ; do
  if [ $# -gt 1 ] && [ $1 == "--admin-password" ]; then
    shift
    if [[ $1 == --* ]]; then
      echo 'Password argument is missing'
      usage
    fi
    ADMIN_PASS=$(escape $1)
    echo 'Admin password saved.'
  elif [ $1 == "--admin-password" ]; then
    echo 'Password argument is missing'
    usage

  elif [ $# -gt 1 ] && [ $1 == "--org" ]; then
    shift
    if [[ $1 == --* ]]; then
      echo 'Organization name is missing'
      usage
    fi
    ORG_NAME=$1
    echo 'Organization name saved.'
  elif [ $1 == "--org" ]; then
    echo 'Organization name is missing'
    usage

  elif [ $# -gt 1 ] && [ $1 == "--app" ]; then
    shift
    if [[ $1 == --* ]]; then
      echo 'App name is missing'
      usage
    fi
    APP_NAME=$1
    echo 'App name saved.'
  elif [ $1 == "--app" ]; then
    echo 'App name is missing'
    usage

  elif [ $1 == "--push-provider" ]; then
    shift
    PROVIDER=$1
    shift
    if [ $# -gt 1 ] && [ $PROVIDER == "google" ]; then
      PROVIDER_ALIAS=$1
      if [[ $PROVIDER_ALIAS == --* ]]; then
        echo "Invalid argument \"$PROVIDER_ALIAS\" a name for a push provider was expected."
        usage
      fi
      shift
      PROVIDER_KEY=$1
      if [[ $PROVIDER_KEY == --* ]]; then
        echo "Invalid argument \"$PROVIDER_KEY\" a key for a push provider was expected."
        usage
      fi
      echo "Google provider \"$PROVIDER_ALIAS\" saved."
      #echo "Created JSON: {\"name\":\"$PROVIDER_ALIAS\", \"provider\":\"google\", \"apiKey\":\"$PROVIDER_KEY\"}"
      echo "echo 'Setup the google push provider with the alias \"${PROVIDER_ALIAS}\"'" >> $SCRIPT_HOME/post_setup2.sh
      echo "curl -X POST -s -i -H \"Accept: application/json\" -H \"Accept-Encoding: gzip, deflate\" -H \"Authorization: Bearer \${ADMIN_TOKEN}\" -d '{\"name\":\"${PROVIDER_ALIAS}\", \"provider\":\"google\", \"apiKey\":\"${PROVIDER_KEY}\"}' \"\${BASE_URL}/netmoms/cyclecalendar/notifiers\"" >> $SCRIPT_HOME/post_setup2.sh
    elif [ $PROVIDER == "google" ]; then
      echo 'Arguments missing for provider "google".'
      usage
    elif [ $# -gt 3 ] && [ $PROVIDER == "apple" ]; then
      PROVIDER_ALIAS=$1
      if [[ $PROVIDER_ALIAS == --* ]]; then
        echo "Invalid argument \"$PROVIDER_ALIAS\" a name for a push provider was expected."
        usage
      fi
      shift
      PROVIDER_ENV=$1
      if [[ $PROVIDER_ENV != 'production' ]] && [[ $PROVIDER_ENV != 'development' ]]; then
        echo "Unsupported environment \"$PROVIDER_ENV\", expecting production or development."
        usage
      fi
      shift
      PROVIDER_CERT=$1
      if [ ! -r $PROVIDER_CERT ] || [ ! -s $PROVIDER_CERT ]; then
        echo "Invalid argument \"$PROVIDER_CERT\" a certificate was expected (file not found or file is empty)."
        usage
      fi
      shift
      PROVIDER_PASSWORD=$(escape $1)
      if [ $(openssl pkcs12 -noout -in "$PROVIDER_CERT" -passin "pass:$PROVIDER_PASSWORD" 2> /dev/null; echo $?) -eq 1 ]; then
        echo 'Wrong password or wrong keystore format.'
        usage
      fi
      echo "Ready to use \"${PROVIDER_CERT}\" with password \"${PROVIDER_PASSWORD}\" for the apple provider with the alias \"${PROVIDER_ALIAS}\""
      echo "echo 'Setup the apple push provider for $PROVIDER_ENV with the alias \"${PROVIDER_ALIAS}\"'" >> $SCRIPT_HOME/post_setup2.sh
      echo "curl -X POST -s -i -H \"Expect:\" -H \"Accept: application/json\" -H \"Accept-Encoding: gzip, deflate\" -H \"Authorization: Bearer \${ADMIN_TOKEN}\" -F \"name=$PROVIDER_ALIAS\" -F \"provider=apple\" -F \"environment=$PROVIDER_ENV\" -F \"p12Certificate=@$PROVIDER_CERT\" -F \"certificatePassword=$PROVIDER_PASSWORD\" \"\${BASE_URL}/netmoms/cyclecalendar/notifiers\"">> $SCRIPT_HOME/post_setup2.sh
    elif [ $PROVIDER == "apple" ]; then
      echo 'Arguments are missing for provider "apple".'
      usage
    elif [ -z "$PROVIDER" ]; then
      echo 'Multiple arguments for --push-provider are missing.'
      usage
    else
      echo "Argument \"$PROVIDER\" is not expected here a provider like google or apple was expected."
      usage
    fi
  else
    echo "Unknown argument \"$1\"."
    usage
  fi
  shift
done

# building the rest of the post setup script
echo "APP_NAME=$APP_NAME" >> $SCRIPT_HOME/post_setup.sh
echo "ORG_NAME=$ORG_NAME" >> $SCRIPT_HOME/post_setup.sh
cat $SCRIPT_HOME/post_setup2.sh >> $SCRIPT_HOME/post_setup.sh
echo "docker rm -f usergrid; docker run --log-driver=syslog --detach --name usergrid --env EXTERNAL_IP=${EXTERNAL_IP} --env ORG_NAME=${ORG_NAME} --env APP_NAME=${APP_NAME} --env AWS_ACCESS_KEY=${AWS_ACCESS_KEY} --env AWS_SECRET_KEY=${AWS_SECRET_KEY} --link elasticsearch:elasticsearch --link cassandra:cassandra -p 8080:8080 -p 8443:8443 -t usergrid">>$SCRIPT_HOME/post_setup.sh
rm $SCRIPT_HOME/post_setup2.sh 2> /dev/null
rm $SCRIPT_HOME/../usergrid/setup.sh 2> /dev/null
mv $SCRIPT_HOME/post_setup.sh $SCRIPT_HOME/../usergrid/setup.sh
chmod +x $SCRIPT_HOME/../usergrid/setup.sh


set -x

# cd into the directory this script is stored in
cd $SCRIPT_HOME

# where to copy files - destination folder has to be named `share`
FILE_LOCATION=/home/core/share

DESTINATION=$SSH_ALIAS:$FILE_LOCATION

# remove old files
ssh -v -o StrictHostKeyChecking=no $SSH_ALIAS "sudo rm -rf $FILE_LOCATION; mkdir -p $FILE_LOCATION"

# copy files to aws machine
scp aws-provision.sh provision.sh cloudconfig.yaml $DESTINATION
scp -r ../java ../usergrid-dev ../usergrid ../cassandra ../elasticsearch $DESTINATION

set +x

echo "running aws-provision.sh using ssh (${FILE_LOCATION}/aws-provision.sh $AWS_ACCESS_KEY $AWS_SECRET_KEY \"$ADMIN_PASS)\""
ssh $SSH_ALIAS "/bin/bash $FILE_LOCATION/aws-provision.sh ${AWS_ACCESS_KEY} $AWS_SECRET_KEY $ORG_NAME $APP_NAME \"$ADMIN_PASS\""
