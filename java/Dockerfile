#
# based on docker's official oracle java 8 dockerfile
#
# https://github.com/dockerfile/java
# https://github.com/dockerfile/java/tree/master/oracle-java8
#

# pull base image
FROM ubuntu:14.10

ENV DEBIAN_FRONTEND noninteractive

# basic setup similar to docker's official ubuntu base image configuration
# see https://github.com/dockerfile/ubuntu/blob/master/Dockerfile
RUN \
  sed -i 's/# \(.*multiverse$\)/\1/g' /etc/apt/sources.list && \
  apt-get update && \
  apt-get -y upgrade && \
  apt-get install -y software-properties-common && \
  apt-get install -y byobu curl git htop man unzip vim wget

# set timezone
RUN \
  echo 'Europe/Berlin' > /etc/timezone && \
  dpkg-reconfigure tzdata

# install oracle java
RUN \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/cache/oracle-jdk8-installer

# commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# default command
CMD ["bash"]
