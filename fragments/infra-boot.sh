#!/bin/bash
#
# Prepare an OpenShift node VM for configuration by Ansible
#
# CONSTANTS
#
# The device to mount to store Docker images and containers
VOLUME_ID=$DOCKER_VOLUME_ID

# Exit on first fail or on reference to an undefined variable
set -eu
set -x

# Return the exit code of the last non-zero command in a pipe (or 0 on success)
set -o pipefail

source /usr/local/share/openshift-on-openstack/common_functions.sh
source /usr/local/share/openshift-on-openstack/common_openshift_functions.sh


# Setup eth1 only if it's present
grep eth1 /proc/net/dev && ifup eth1

sudo_set_secure_path "/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"
sudo_enable_from_ssh

docker_install_and_enable
docker_set_trusted_registry 0.0.0.0/0

if [ $(docker_version major) -lt 2 -a $(docker_version minor) -lt 10 ]
then
    systemd_add_docker_socket
fi

# lvmetad allows new volumes to be configured and made available as they appear
# This is good for dynamically created volumes in a cloud provider service
systemctl enable lvm2-lvmetad
systemctl start lvm2-lvmetad

if [ -n "$VOLUME_ID" ]
then
    docker_set_storage_device $VOLUME_ID
fi

notify_success "OpenShift node has been prepared for running docker."
