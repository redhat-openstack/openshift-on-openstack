#!/bin/bash
#
# Remove a host entry from the Dnsmasq host table on the infrastructure host
#
# ENVVARS
#   SKIP_DNS = boolean: local DNS updates are disabled
#   node_name = "<hostname>"

# Exit on fail or bad VAR expansion
set -eux

# ============================================================================
# MAIN
# ============================================================================

# If Local DNS is disabled, make no changes
[ "$SKIP_DNS" = "true" ] && exit 0

# Locate the hosts file
# Use /host/etc/hosts for atomic container /etc/hosts for RHEL
[ -e /run/ostree-booted ] && etc_file=/host/etc/hosts || etc_file=/etc/hosts

# Save a copy of the current host file
cp $etc_file ${etc_file}.bkp

# Remove the node IP entry from the hosts file (saving the backup)
grep -v "$node_name" ${etc_file}.bkp > $etc_file

# Restart the DNS server to re-read the hosts file
if [ -e /run/ostree-booted ]; then
    # Find the DNS docker container and restart it
    ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')
    docker restart $ctid
else
    # Restart the host based DNS service process
    systemctl restart dnsmasq
fi

# remove the node from the openshift service using the first master
ansible masters[0] -m shell \
        -u cloud-user --sudo -i /var/lib/ansible/inventory \
        -a "oc --config ~/.kube/config delete node $node_name" || true

# remove from the local list
cp /var/lib/openshift_nodes /var/lib/openshift_nodes.bkp
grep -v "$node_name" /var/lib/openshift_nodes.bkp \
     > /var/lib/openshift_nodes || true

echo "Deleted node $node_name"
