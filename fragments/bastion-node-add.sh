#!/bin/bash

set -eux

# ENVVARS
#   node_etc_host = "<IP Address> <hostname>"

#
# FILES
#   /etc/hosts - the host database file on RPM based host
#

# ============================================================================
# MAIN
# ============================================================================

NODESFILE=/var/lib/ansible/${node_type}_list
mkdir -p /var/lib/ansible/
touch $NODESFILE
grep -q "$node_hostname" $NODESFILE || echo $node_hostname >> $NODESFILE

echo "$node_etc_host" >> /etc/hosts-todo
[ -e /run/ostree-booted ] && cp /etc/hosts-todo /host/etc/hosts || true
