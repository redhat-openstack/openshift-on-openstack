#!/bin/bash
set -eux

[ "$SKIP_DNS" = "true" ] && exit 0

[ -e /run/ostree-booted ] && etc_file=/host/etc/hosts || etc_file=/etc/hosts
cp $etc_file ${etc_file}.bkp
grep -v "$node_name" ${etc_file}.bkp > $etc_file

if [ -e /run/ostree-booted ]; then
    ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')
    docker restart $ctid
else
    systemctl restart dnsmasq
fi

ansible masters[0] -m shell -a "oc --config ~/.kube/config delete node $node_name" -u cloud-user --sudo -i /var/lib/ansible/inventory || true
cp /var/lib/openshift_nodes /var/lib/openshift_nodes.bkp
grep -v "$node_name" /var/lib/openshift_nodes.bkp > /var/lib/openshift_nodes || true
echo "Deleted node $node_name"
