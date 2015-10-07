#!/bin/bash

set -ex

retry yum -y install bridge-utils

retry yum -y install https://kojipkgs.fedoraproject.org//packages/flannel/0.5.3/5.fc24/x86_64/flannel-0.5.3-5.fc24.x86_64.rpm

cd /root

cp /etc/origin/node/system:node:$(hostname).key etcd.key
cp /etc/origin/node/system:node:$(hostname).crt etcd.crt

CA=/etc/origin/node/ca.crt
CERT=$(pwd)/etcd.crt
KEY=$(pwd)/etcd.key

curl -L --cacert $CA --cert $CERT --key $KEY https://openshift-master.example.com:4001/v2/keys/coreos.com/network/config -XPUT --data-urlencode value@flannel-config.json

cp flannel-sysconfig /etc/sysconfig/flanneld

systemctl restart flanneld

DOCKER_NET=$(ip a show docker0 | grep inet | awk '{print $2}')
ip a del $DOCKER_NET dev docker0
systemctl restart docker

systemctl restart origin-node
