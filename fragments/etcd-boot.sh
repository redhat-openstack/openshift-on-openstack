#!/bin/bash
#
# Prepare an etcd node VM for configuration by Ansible
#
# ENVVARS
#   WC_NOTIFY - a curl URL from an OpenStack WaitCondition
#               send status to OpenStack
#   SKIP_DNS - local DNS is disabled: do not try to make updates

# Exit on first fail or on reference to an undefined variable
set -eu
set -x

# Return the exit code of the last non-zero command in a pipe (or 0 on success)
set -o pipefail

source /usr/local/share/openshift-on-openstack/common_functions.sh
source /usr/local/share/openshift-on-openstack/common_openshift_functions.sh

[ "$SKIP_DNS" != "True" ] && add_nameserver $DNS_IP

disable_peerdns eth0

sudo_set_secure_path "/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"
sudo_enable_from_ssh

notify_success "Node has been prepared for running etcd."
