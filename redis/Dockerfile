FROM ubuntu:14.04
RUN apt-get update && apt-get install -y redis-server
#RUN "sysctl -w net.core.somaxconn=65535"
#RUN echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
#RUN echo never > /sys/kernel/mm/transparent_hugepage/enabled
EXPOSE      6379
ENTRYPOINT  ["/usr/bin/redis-server"]

