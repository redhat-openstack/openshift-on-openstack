#!/bin/bash
set -eux

echo "$node_etc_host" >> /host/etc/hosts
ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')

if [ -e /run/ostree-booted ]; then
    docker restart $ctid
else
    systemctl restart dnsmasq
fi
