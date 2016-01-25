#!/bin/bash
set -eux

[ -e /run/ostree-booted ] && etc_file=/host/etc/hosts || etc_file=/etc/hosts
cp $etc_file ${etc_file}.bkp
grep -v "$node_name" ${etc_file}.bkp > $etc_file

if [ -e /run/ostree-booted ]; then
    ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')
    docker restart $ctid
else
    systemctl restart dnsmasq
fi
