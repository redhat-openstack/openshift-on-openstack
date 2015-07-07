#!/bin/bash

set -eu
set -x
set -o pipefail

# master and nodes
# Disable NetworkManager
systemctl disable NetworkManager || true
/sbin/chkconfig network on || true
systemctl stop NetworkManager &>/dev/null || true


# master and nodes
# Set the DNS to the one provided
sed -i 's/search openstacklocal/&\nnameserver $DNS_IP/' /etc/resolv.conf

# master and nodes
retry yum install -y deltarpm
retry yum -y update
