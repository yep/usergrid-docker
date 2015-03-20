# install cassandra from datastax repository

FROM java

ENV DEBIAN_FRONTEND noninteractive
WORKDIR /root

# add source for cassandra
RUN echo "deb http://debian.datastax.com/community stable main" | tee -a /etc/apt/sources.list.d/cassandra.sources.list
RUN curl https://debian.datastax.com/debian/repo_key | apt-key add -
RUN apt-get update -o Dir::Etc::sourcelist="sources.list.d/cassandra.sources.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

# install cassandra
RUN apt-get install -yq cassandra=1.2.19
RUN sed -i -e "s/^rpc_address.*/rpc_address: 0.0.0.0/" /etc/cassandra/cassandra.yaml

# persist database and logs between container starts
VOLUME ["/var/lib/cassandra", "/var/log/cassandra"]

# set default command when starting container with "docker run"
CMD /root/run.sh

# exposed ports:
#  9160 cassandra thrift interface
EXPOSE 9160

ADD run.sh /root/run.sh
