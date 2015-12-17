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

# build usergrid from source

FROM yep1/usergrid-java

WORKDIR /root
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# build usergrid
# this is done in one run step so less files are included in the layers of the
# docker image, making it smaller.
RUN \
  echo "+++ install tomcat and packages required for compilation" && \ 
  apt-get update && \
  apt-get install -y maven curl tomcat7 git-core && \
  \
  echo "+++ fix tomcat7 init script: add missing java8 location" && \
  sed -i "s#/usr/lib/jvm/java-7-oracle#/usr/lib/jvm/java-7-oracle /usr/lib/jvm/java-8-oracle#g" /etc/init.d/tomcat7 && \
  \
  echo "+++ get usergrid source, set logging level" && \
  git clone --single-branch --branch master --depth 50 https://github.com/apache/usergrid.git usergrid && \
  cd usergrid && \
  git checkout c6945e3d6f608d1333c269657eb47064866d3e0b && \
  grep -rl log4j.rootLogger=INFO stack | xargs sed -i 's#log4j.rootLogger=INFO#log4j.rootLogger=WARN#g' && \
  \
  echo "+++ build usergrid" && \
  cd /root/usergrid/sdks/java && \
  mvn --quiet clean install -DskipTests -DskipIntegrationTests && \
  mvn --quiet install && \
  cd /root/usergrid/stack && \
  mvn --quiet clean install -DskipTests -DskipIntegrationTests && \
  \
  echo "+++ cleanup" && \
  rm -rf /var/lib/tomcat7/webapps/ROOT && \
  mv /root/usergrid/stack/rest/target/ROOT.war /var/lib/tomcat7/webapps && \
  mv /root/usergrid/stack/config/src/main/resources/usergrid-default.properties /usr/share/tomcat7/lib/usergrid-deployment.properties && \
  apt-get purge --auto-remove -y maven git-core ant && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /root/usergrid

# default command when starting container with "docker run"
CMD /root/run.sh

# exposed ports:
#  8080 usergrid http interface
#  8443 usergrid https interface
EXPOSE 8080 8443

# runtime configuration script: since this is updated frequently during development, add it last
COPY run.sh /root/run.sh
