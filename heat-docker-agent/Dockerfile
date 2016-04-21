FROM centos:centos7
MAINTAINER jprovazn@redhat.com
ENV container docker

ADD configure_container_agent.sh /tmp/
RUN /tmp/configure_container_agent.sh

#create volumes to share the host directories
#VOLUME [ "/var/lib/cloud"]
#VOLUME [ "/var/lib/heat-cfntools" ]

#set DOCKER_HOST environment variable that docker-compose would use
ENV DOCKER_HOST unix:///var/run/docker.sock

CMD /usr/bin/os-collect-config
