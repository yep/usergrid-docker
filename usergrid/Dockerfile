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

# container to run usergrid (without building it)

FROM java

WORKDIR /root
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# install tomcat
RUN apt-get update && \
    apt-get install -y tomcat7 && \
    rm -rf /var/lib/apt/lists/*

# fix tomcat7 init script: add missing java8 location
RUN sed -i "s/\/usr\/lib\/jvm\/java-7-oracle/\/usr\/lib\/jvm\/java-7-oracle \/usr\/lib\/jvm\/java-8-oracle/g" /etc/init.d/tomcat7

# the ROOT.war file has to be created using the usergrid-dev container
ADD ROOT.war /root/usergrid/ROOT.war

ADD usergrid-default.properties /root/usergrid/stack/config/src/main/resources/usergrid-default.properties
ADD portal /root/usergrid/portal

# install usergrid in tomcat
RUN rm -rf /var/lib/tomcat7/webapps/ROOT && \
    cp /root/usergrid/ROOT.war /var/lib/tomcat7/webapps

# set default command when starting container with "docker run"
CMD /root/run.sh

# exposed ports:
#  8080 usergrid http interface
EXPOSE 8080

# add runtime configuration script. since this is updated frequently during development, add last
ADD run.sh /root/run.sh
