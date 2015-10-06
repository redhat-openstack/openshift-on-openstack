#!/bin/bash

set -x

retry yum -y install \
    http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

retry yum install -y --enablerepo=epel jq


cp /etc/origin/node/system:node:$(hostname).key etcd.key
cp /etc/origin/node/system:node:$(hostname).crt etcd.crt

CA=/etc/origin/node/ca.crt
CERT=$(pwd)/etcd.crt
KEY=$(pwd)/etcd.key

NETWORK=$(curl --cacert $CA --cert $CERT --key $KEY https://openshift-master.example.com:4001/v2/keys/openshift.io/registry/sdnnetworks/default | jq --raw-output .node.value | jq --raw-output .network)
SUBNET=$(curl --cacert $CA --cert $CERT --key $KEY https://openshift-master.example.com:4001/v2/keys/openshift.io/registry/sdnsubnets/$(hostname) | jq --raw-output .node.value | jq --raw-output .subnet)

ip link set eth1 down # just in case
brctl addbr br1
ip addr add $NETWORK dev br1
brctl addif br1 eth1
ip link set eth1 up
ip link set br1 up

ESCAPED_SUBNET=$(echo $SUBNET | sed -e 's/\//\\\//')
sed -i -e "s/\$DOCKER_NETWORK_OPTIONS/-b=br1 --fixed-cidr=$ESCAPED_SUBNET/" /usr/lib/systemd/system/docker.service

systemctl daemon-reload
systemctl restart docker
