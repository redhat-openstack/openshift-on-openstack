#!/bin/bash
#
# Prepare an OpenShift node VM for configuration by Ansible
#
# ENVVARS
#   WC_NOTIFY - a curl URL from an OpenStack WaitCondition
#               send status to OpenStack
#   SKIP_DNS - local DNS is disabled: do not try to make updates
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

# =============================================================================
# FUNCTIONS
# =============================================================================

#
# - DNS ---------------------------------------------------------
#

# boolean: true if local DNS service is enabled
function dns_updates_enabled() {
    [ "$SKIP_DNS" != "true" ]
}


function disable_peerdns() {
    # INTERFACE=$1
    sed -i '/^PEERDNS=/s/=.*/="no"/' /etc/sysconfig/network-scripts/ifcfg-$1
}

# workaround for openshift-ansible - symlinks are created in /usr/local/bin but
# this path is not by default in sudo secure_path so ansible fails
function sudo_set_secure_path() {
    # SECURE_PATH=$1
    sed -i "/secure_path = /s|=.*|= $1|" /etc/sudoers
}

#
# - docker ---------------------------------------------------------
#

function docker_install_and_enable() {
    if ! rpm -q docker
    then
        yum -y install docker || notify_failure "could not install docker"
    fi
    systemctl enable docker
}


# 
function docker_version() {
    # MAJ_MIN=$1 - 'major' or 'minor'
    local version=$(rpm -q docker --qf '%{VERSION}')
    [ $1 = "major" ] && echo $version | cut -d. -f1 && return
    [ $1 = "minor" ] && echo $version | cut -d. -f2 && return
    echo $version
}

function docker_set_trusted_registry() {
    # TRUSTED_REGISTRY=$1
    echo "INSECURE_REGISTRY='--insecure-registry $1'" >> /etc/sysconfig/docker
}

#
# - systemd ---------------------------------------------------------
#

function systemd_add_docker_socket() {
    
    # Workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1289851
    # can be removed once docker 1.10 is released
    
    # make a "local" copy of the docker service unit file
    cp /lib/systemd/system/docker.service /etc/systemd/system/docker.service
    # Add a new unit file requirement
    sed -i '/Wants=docker-storage-setup.service/aRequires=docker.socket' \
        /etc/systemd/system/docker.service

    # create the docker socket unit file
    cat << EOF > /etc/systemd/system/docker.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=root

[Install]
WantedBy=sockets.target
EOF

    # Force re-read of systemd configuration and apply
    systemctl daemon-reload
}


############################################################################
# MAIN
############################################################################

if dns_updates_enabled
then
    add_nameserver $DNS_IP
fi

disable_peerdns eth0
ifup eth1

sudo_set_secure_path "/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin"
sudo_enable_from_ssh

docker_install_and_enable
docker_set_trusted_registry 0.0.0.0/0

if [ $(docker_version major) -lt 2 -a $(docker_version minor) -lt 10 ]
then
    systemd_add_docker_socket
fi

if [ -n "$VOLUME_ID" ]
then
    docker_set_storage_device $DOCKER_VOLUME_ID
fi

# lvmetad allows new volumes to be configured and made available as they appear
# This is good for dynamically created volumes in a cloud provider service
systemctl enable lvm2-lvmetad
systemctl start lvm2-lvmetad

notify_success "OpenShift node has been prepared for running docker."
