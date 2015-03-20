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

# this script is run if you provision vagrant using `vagrant provision`
# it is called from `Vagrantfile`

echo '+ vagrant-provision.sh'

# unfortunately, the usergrid admin portal needs to know the ip it is
# available at. this ip is only known to the `Vagrantfile`.
#
# therefore, the `Vagrantfile` passes the external ip of the vm into this
# provision shell script as parameter $1.
#
# the vagrant vm then passes the external ip on to the usergrid container.
EXTERNAL_IP=$1
echo using EXTERNAL_IP = $EXTERNAL_IP

# continue with the script used by both aws and vagrant
source /home/core/share/provision/provision.sh
