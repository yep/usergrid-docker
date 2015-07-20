# install cassandra from datastax repository

FROM nm-java

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /root

# add source for cassandra and install it
RUN \
  echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/cassandra.sources.list && \
  curl https://debian.datastax.com/debian/repo_key | apt-key add -  && \
  apt-get update && \
  apt-get update -o Dir::Etc::sourcelist="sources.list.d/cassandra.sources.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" && \
  apt-get install -yq cassandra=1.2.19 net-tools && \
  sed -i -e "s/^rpc_address.*/rpc_address: 0.0.0.0/" /etc/cassandra/cassandra.yaml && \
  rm -rf /var/lib/apt/lists/*

# persist database and logs between container starts
VOLUME ["/var/lib/cassandra", "/var/log/cassandra"]

# set default command when starting container with "docker run"
CMD /root/run.sh

# exposed ports:
#  9160 cassandra thrift interface
#  9042 cassandra native transport
EXPOSE 9160 9042

ADD run.sh /root/run.sh
