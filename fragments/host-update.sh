#!/bin/bash
#
# Ensure that the host OS packages are current
#
#   On an Atomic host, upgrade the host tree
#   On traditional host, update RPMs
#
# ENVVARS:
#   WC_NOTIFY: a curl CLI fragment to notify OpenStack Heat of the completion
#              status of the script.
#              Provided by an OpenStack WaitCondition object

# Exit on fail, bad VAR expansion
set -eux
# return the last (right most) non-zero status from pipes (or 0 on success) 
set -o pipefail

source /usr/local/share/openshift-on-openstack/common_functions.sh

# ============================================================================
# MAIN
# ============================================================================

# Check for Atomic Host
if [ -e /run/ostree-booted ]
then
    # Update the OS tree
    atomic host upgrade || notify_failure "failed to run 'atomic host upgrade'"
else
    # Update using traditional RPMs
    #retry yum install -y deltarpm || notify_failure "could not install deltarpm"
    [ "$SYSTEM_UPDATE" = "True" ] && (retry yum -y update || notify_failure "could not update RPMs")
fi
