#!/bin/bash
#
# Configure dnsmasq on the infrastructure node
# Add LDAP and load balancer host entries if provided
#
# ENVVARS:
#
#   SKIP_DNS   - Boolean: local DNS is disabled
#   DOMAINNAME - The domain for the OpenShift service: components and apps
#
#   LDAP_IP       - The IP address of the LDAP server used for auth and id
#   LDAP_HOSTNAME - The host name for the LDAP server
#
#   LB_IP         - The IP address of the load balancer VM
#   LB_HOSTNAME   - The host portion of the load balancer name
#   LB_DOMAIN     - The domain portion of the load balancer name
#

# Exit on any error
set -eu
# Return the last non-zero exit code from a pipe (or 0 for success)
set -o pipefail


# =============================================================================
# MAIN
# =============================================================================

# If local DNS is disabled, make no changes
[ "$SKIP_DNS" = "true" ] && exit 0

#
# Configure initial internal DNS service: Set domain name
#
cat <<EOF >/etc/dnsmasq.conf
# this file is generated/overwritten by os-collect-config
strict-order
domain-needed
local=/$DOMAINNAME/
bind-dynamic
resolv-file=/etc/resolv.conf
log-queries
EOF

# Add LDAP server entry to DNS
if [ -n "$LDAP_HOSTNAME" -a -n "$LDAP_IP" ]; then
    echo "$LDAP_IP $LDAP_HOSTNAME" >> /etc/hosts
fi

# Add Load balancer entry to DNS
if [ -n "$LB_HOSTNAME" -a -n "$LB_IP" ]; then
    echo "$LB_IP $LB_HOSTNAME $LB_HOSTNAME.$LB_DOMAIN" >> /etc/hosts
fi
