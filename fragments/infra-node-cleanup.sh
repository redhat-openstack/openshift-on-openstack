#!/bin/bash
set -eux

cp /host/etc/hosts /host/etc/hosts.bkp
grep -v "$node_name" /host/etc/hosts.bkp > /host/etc/hosts


if [ -e /run/ostree-booted ]; then
    ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')
    docker restart $ctid
else
    systemctl restart dnsmasq
fi
