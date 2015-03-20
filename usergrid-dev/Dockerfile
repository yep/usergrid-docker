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

# build usergrid from source

FROM java

WORKDIR /root
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# install tomcat and build dependencies
RUN apt-get update && \
    apt-get install -y maven curl tomcat7 npm nodejs-legacy git-core

# fix tomcat7 init script: add missing java8 location
RUN sed -i "s/\/usr\/lib\/jvm\/java-7-oracle/\/usr\/lib\/jvm\/java-7-oracle \/usr\/lib\/jvm\/java-8-oracle/g" /etc/init.d/tomcat7

# only clone last 50 commits for a faster cloning operation
RUN git clone --branch two-dot-o --depth 50 https://github.com/apache/incubator-usergrid.git usergrid

# build usergrid from source
RUN cd usergrid && \
    git checkout b53cb07f376fcdff8ce0b3226bbb07843f12d4e9
RUN sed -i "s/\xC3\xB8//g" /root/usergrid/stack/corepersistence/collection/src/test/java/org/apache/usergrid/persistence/collection/util/EntityHelper.java && \
    sed -i "s/us-east-1/eu-west-1/g" /root/usergrid/stack/corepersistence/queue/src/main/java/org/apache/usergrid/persistence/queue/QueueFig.java && \
    rm -f rm -f /root/usergrid/stack/.editorconfig && \
    cd usergrid/sdks/java && \
    mvn clean install -DskipTests=true && \
    mvn install
RUN cd usergrid/stack && \
    mvn clean install -DskipTests=true -Dusergrid-custom-spring-properties=classpath:/usergrid-custom.properties

# install usergrid in tomcat
RUN rm -rf /var/lib/tomcat7/webapps/ROOT && \
    cp usergrid/stack/rest/target/ROOT.war /var/lib/tomcat7/webapps

# build admin portal
RUN npm install -g grunt-cli && \
    sed -i "s/Usergrid.overrideUrl = 'https:\/\/api.usergrid.com\/';/Usergrid.overrideUrl = 'http:\/\/172.17.8.101:8080\/';/g" usergrid/portal/config.js && \
    cd usergrid/portal && ./build.sh

# set default command when starting container with "docker run"
CMD /root/run.sh

# exposed ports:
#  8080 usergrid http interface
EXPOSE 8080

# add runtime configuration script. since this is updated frequently during development, add last
ADD run.sh /root/run.sh
