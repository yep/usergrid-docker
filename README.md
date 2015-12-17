Usergrid on Docker
==================

A collection of containers to run [Usergrid](https://usergrid.apache.org) on [Docker](https://www.docker.com).

There are the following containers:

 - [java](https://hub.docker.com/r/yep1/usergrid-java) - Ubuntu base image with Oracle JVM version 8 - [github](https://github.com/yep/usergrid-java) - (MIT license)
 - [cassandra](https://hub.docker.com/r/yep1/usergrid-cassandra/) - version 1.2 - [github](https://github.com/yep/usergrid-cassandra)
 - [elasticsearch](https://hub.docker.com/r/yep1/usergrid-elasticsearch/) - version 1.4 - [github](https://github.com/yep/usergrid-elasticsearch) - (MIT license)
 - [usergrid](https://hub.docker.com/r/yep1/usergrid) - version 2.1 - [github](https://github.com/yep/usergrid-docker)

To see how the containers play together, have a look at the `provision.sh` script from the `provision` directory.

Local testing using [Vagrant](http://vagrantup.com) and deployment to [Amazon Web Services (AWS)](http://aws.amazon.com) are supported, see below.


Usage
-----

Start Cassandra and Elasticsearch:

    docker run --detach --name cassandra --volume $(pwd)/cassandra-data:/var/lib/cassandra yep1/usergrid-cassandra
    docker run --detach --name elasticsearch --volume $(pwd)/elasticsearch-data:/data yep1/usergrid-elasticsearch

Start Usergrid, configuration is done using environment variables (--env), see below:

    docker run --detach --name usergrid --env ADMIN_PASS=password --env ORG_NAME=org --env APP_NAME=app --link elasticsearch:elasticsearch --link cassandra:cassandra -p 8080:8080 yep1/usergrid


Environment Variables
---------------------

The following [environment variables](http://docs.docker.com/userguide/dockerlinks/#environment-variables) are used to access [backing services](http://12factor.net/backing-services):

    CASSANDRA_PORT_9160_TCP_ADDR
    CASSANDRA_PORT_9160_TCP_PORT
    ELASTICSEARCH_PORT_9300_TCP_ADDR
    ELASTICSEARCH_PORT_9300_TCP_PORT

Configuration variables used in the `usergrid` container:

    ADMIN_USER
    ADMIN_PASS
    ADMIN_MAIL
    ORG_NAME
    APP_NAME
    AWS_ACCESS_KEY
    AWS_SECRET_KEY
    CLUSTER_NAME
    TOMCAT_RAM


Build
-----

Get the submodules first:

    git clone https://github.com/yep/usergrid-docker.git
    cd usergrid-docker
    git submodule update --init

First, build the java base container:

    cd java && build -t java .

Then, in each `Dockerfile` change `FROM yep1/usergrid-java` to `FROM java` to use the local java container created above.

Finally, build the containers:

    cd cassandra && build -t cassandra .
    cd elasticsearch && build -t elasticsearch .
    cd usergrid && build -t usergrid .


Run on Vagrant
--------------

To run the containers on Vagrant, install the following dependencies:

 - [Virtualbox](http://virtualbox.org)
 - [Vagrant](http://vagrantup.com)

On windows, you may additionally have to install `rsync` and `ssh` using something like [mingw](http://www.mingw.org) or [cygwin](http://www.cygwin.com).

In your `Vagrantfile`, set the IP your VM will be reachable at in the local network:

    ip = YOUR_IP

Then, in the root directory of the repository execute the following commands:

    vagrant up

This should automatically download and start an instance of [CoreOS](http://coreos.com).

If you make any changes to the configuration, update the files inside the VM and restart the containers with

    vagrant rsync && vagrant provision

Using Vagrant, it is simple to start up multiple virtual machines (VMs) simulatenously by changing the `num_instances` parameter in the `Vagrantfile`. You can also adjust the `vb_memory` and `vb_cpu` parameters to change the amount of memory and number of CPUs available to the VM.


Run on AWS
----------

Deployment to Amazon Web Services [(AWS)](http://aws.amazon.com) can be done using the `aws-deploy.sh` script from the `provision` directory.

Getting started:

 - Generate key pair in the aws console or add a locally generated key pair
 - Create a user called `usergrid` in IAM, download the credentials and attach the `AmazonSQSFullAccess` policy
 - Export aws credentials as environment variables: `export AWS_ACCESS_KEY=<key>` and `export AWS_SECRET_KEY=<secret>`
 - Start the latest stable CoreOS community ami with hvm (hardware virtualization) of size `m3.medium`. At time of writing, latest is `ami-0e300d13` called `CoreOS-stable-607.0.0-hvm`
 - Set up an SSH alias called `aws` so you can ssh into the machine by typing `ssh aws` without entering a password
 - Run `aws_deploy.sh`

Apple push notification (apns) setup note:

When generating the `notifier` in usergrid, a .p12 certificate is required.

To create this .p12 certificate, you have to select BOTH the private key (of type `private key`) and the public key signed by Apple (of type `certificate`) in the Apple keychain OSX app at the same time and then export both of them into one .p12 file.


Usergrid Documentation
----------------------

 * [Usergrid Backend as a Service (BaaS) Documentation](http://apigee.com/docs/api-baas/content/build-apps-home)
 * [Usergrid REST Endpoints](http://apigee.com/docs/app-services/content/rest-endpoints)


Postman
-------

For debugging of REST commands, you can use [Postman](http://getpostman.com).

Import the postman collection `usergrid.json.postman_collection` and environment `usergrid.json.postman_environment` from the `postman` directory.

To use `postman`, request an API token using one of the provided commands and set the `token` parameter in the `environment` of `postman` accordingly. Also set the `ip` parameter in the environment.


Usage
-----

Some useful `vagrant` commands:

 * `vagrant up` - start VM
 * `vagrant ssh` - ssh into VM
 * `vagrant halt` - stop VM
 * `vagrant destroy` - remove VM, run `vagrant up` to start from scratch
 * `vagrant rsync` - update shared folder using rsync
 * `vagrant provision` - run the provion script from the Vagrantfile
 * `vagrant box update` - update CoreOS base box

Some useful `docker` commands, run these from inside of the VM:

 * `docker build -t usergrid .` - build the dockerfile in the current directory and tag the container with `usergrid`
 * `docker run -d --name usergrid --link elasticsearch:elasticsearch --link cassandra:cassandra -t usergrid` - run the container which was built with the above command in the background (detached, -d), expose the usergrid http api port (8080, -p) and make the ports exposed by `elasticsearch` and `cassandra` available by linking the containers together
 * `docker ps` - show container ids of running containers
 * `docker logs -f usergrid` - follow the log of the container with tag `usergrid`
 * `docker stop usergrid` - stop running container with tag `usergrid`
 * `docker run -i -t usergrid /bin/bash` - start an interactive bash shell in the container with tag `usergrid`
 * `docker ps -q|docker stop; docker images -q|xargs docker rmi -f` - stop and delete ALL old docker images to free up disk space

Some useful usergrid command line `ugc` commands:

Install `ugc` with `gem install ugc`. Documentation is [here](https://github.com/apache/incubator-usergrid/tree/master/ugc). For more examples, see the [ugc examples](https://github.com/apache/incubator-usergrid/tree/master/ugc#examples).

 * `ugc profile org` - create profile with name `org`. subsequent commands are applied to this profile.
 * `ugc target url http://$IP:8080/org/app` - use host at $IP, organization called `org` and app called `app`
 * `ugc login --admin $USERNAME@example.com` - log in as one of the admins users `admin` or `orgadmin`. password is the same as the username.
 * `ugc login $USERNAME@example.com` - log in as regular user. there is a default user called `orguser`. password is same as username.
 * `ugc list collections` - list collections. think of it as tables in a relational database. you can list other things as well.

Some useful Virtualbox commands:

 * `VBoxManage hostonlyif remove vboxnet0` - manually delete a hostonly network if it was not properly removed by Virtualbox

Some useful OSX commands:

 * `ifconfig bridge0 delete` - manually delete a bridge if it was not properly removed by Virtualbox


License
-------

    Copyright 2014-2015 Jahn Bertsch
    Copyright 2015 TOMORROW FOCUS News+ GmbH

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

