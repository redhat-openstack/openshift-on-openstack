#!/bin/bash

set -eu
set -o pipefail

cat <<EOF >/etc/dnsmasq.conf
# this file is generated/overwritten by os-collect-config
strict-order
domain-needed
local=/$DOMAINNAME/
bind-dynamic
resolv-file=/etc/resolv.conf
log-queries
EOF

if [ -n "$LDAP_HOSTNAME" -a -n "$LDAP_IP" ]; then
    echo "$LDAP_IP $LDAP_HOSTNAME" >> /etc/hosts
fi

if [ -n "$LB_HOSTNAME" -a -n "$LB_IP" ]; then
    echo "$LB_IP $LB_HOSTNAME $LB_HOSTNAME.$LB_DOMAIN" >> /etc/hosts
fi
