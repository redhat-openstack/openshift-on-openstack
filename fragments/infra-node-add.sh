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
    # Restart the DNS service container (started from infra-boot.sh)
    docker restart dnsmasq
else
    echo "$node_etc_host" >> /etc/hosts
    systemctl restart dnsmasq
fi
