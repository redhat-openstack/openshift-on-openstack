#!/bin/bash
#
# Prepare the Load Balancer host to run ansible for host configuration
#
# ENVVARS
#   DNS_IP:    The IP address of the closest DNS server for name resolution
#   WC_NOTIFY: A curl query prefix to provide status to OpenStack WaitCondition

# Exit immediately on error or on reference to an undefined variable
set -eu
set -x

# Exit with return code of the last non-zero part of a pipe (or 0 for success)
set -o pipefail

# Indicate success to OpenStack via a WaitCondition curl query
function notify_success() {
    # MESSAGE=$1
    $WC_NOTIFY --data-binary  \
               "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

# Indicate failure to OpenStack via a WaitCondition curl query
function notify_failure() {
    $WC_NOTIFY --data-binary \
               "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}

# ==============================================================================
# MAIN
# ==============================================================================

# Add a nameserver line for the local DNS server
if [ -n "$DNS_IP" ]
then
    sed -i '/search openstacklocal.*/a\nnameserver $DNS_IP' /etc/resolv.conf
fi

# Disable updates to the /etc/resolv.conf file for DNS when starting eth0
sed -i '/^PEERDNS=/s/=.*/=no/' /etc/sysconfig/network-scripts/ifcfg-eth0

# workaround for openshift-ansible - Add /usr/local/bin to sudo PATH
#   symlinks are created in /usr/local/bin but this path is not by
#   default in sudo secure_path so ansible fails
sed -i '/secure_path =/s|=.*|= /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin|' \
    /etc/sudoers

# Disable requiretty: allow sudo via SSH
sed -i "/^Defaults.*requiretty/s/^/#/" /etc/sudoers

notify_success "OpenShift node has been prepared for running ansible."
