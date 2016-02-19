#!/bin/bash
set -eux

if [ -e /run/ostree-booted ]; then
    echo "$node_etc_host" >> /host/etc/hosts
    ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')
    docker restart $ctid
else
    echo "$node_etc_host" >> /etc/hosts
    systemctl restart dnsmasq
fi
