#!/bin/bash
#
# Append a host entry to the Dnsmasq host table on the infrastructure host
#
set -eux

# ENVVARS
#   SKIP_DNS = boolean: indicates that local DNS is disabled
#   node_etc_host = "<IP Address> <hostname>"

#
# FILES
#   /host/etc/hosts - the host database file on Atomic Host with DNS container
#   /etc/hosts - the host database file on RPM based host
#

# ============================================================================
# MAIN
# ============================================================================

[ "$SKIP_DNS" = "True" ] && exit 0

# Check for Atomic Host
if [ -e /run/ostree-booted ]; then
    echo "$node_etc_host" >> /host/etc/hosts

    # Find and restart the DNS service container
    ctid=$(docker ps | grep ooshift-dns|awk '{ print $1 }')
    docker restart $ctid
else
    echo "$node_etc_host" >> /etc/hosts
    systemctl restart dnsmasq
fi
