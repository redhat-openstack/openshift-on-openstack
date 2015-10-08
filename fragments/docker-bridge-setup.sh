#!/bin/bash

set -ex

retry yum -y install bridge-utils

retry yum -y install https://kojipkgs.fedoraproject.org//packages/flannel/0.5.3/5.fc24/x86_64/flannel-0.5.3-5.fc24.x86_64.rpm

cp /root/flannel-sysconfig /etc/sysconfig/flanneld

systemctl restart flanneld

DOCKER_NET=$(ip a show docker0 | grep inet | awk '{print $2}')
ip a del $DOCKER_NET dev docker0
systemctl restart docker

systemctl restart origin-node
