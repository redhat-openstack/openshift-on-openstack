#!/bin/bash
#
# Prepare the infrastructure server for Docker and Ansible
#
# ENVVARS
#   WC_NOTIFY - a curl URL fragment from an OpenStack WaitCondition
#               used to signal OpenStack of completion status
#   DNS_IP    - The IP address of the nearest resolver host
#
#   SKIP_DNS  - true|false - enable local DNS service updates
#
#   OPENSHIFT_ANSIBLE_GIT_URL - the URL of a git repository containing the
#                               openshift ansible playbooks and configs
#   OPENSHIFT_ANSIBLE_GIT_REV - the release/revision of the playbooks to use
#

# Exit on first command failure or undefined var reference
set -eu
set -x

# Return the non-zero exit code of the last cmd of a pipe (or 0 for success)
set -o pipefail

source /usr/local/share/openshift-on-openstack/common_functions.sh

# CONSTANTS
#
# The device to mount to store Docker images and containers
VOLUME_ID=$DOCKER_VOLUME_ID

# The auxiliary service container images - for Atomic hosts
HEAT_AGENT_CONTAINER_IMAGE=jprovaznik/ooshift-heat-agent

# Select the EPEL release to make it easier to update
EPEL_RELEASE_VERSION=7-7

# --- DNS functions ----------------------------------------------------------
#
# Disable automatic updates of resolv.conf when an interface comes up
function disable_resolv_updates() {
    # INTERFACE=$1
    sed -i -e '/^PEERDNS=/s/=.*/="no"/' \
        /etc/sysconfig/network-scripts/ifcfg-$1
}


# ----------------------------------------------------------------------------
# Functions for Atomic Host systems
# ----------------------------------------------------------------------------

# check if this is an Atomic host
function is_atomic_host() {
    [ -e /run/ostree-booted ]
}

# remove the docker storage setup service link and re-load the systemd config
function systemd_docker_disable_storage_setup() {
    mv /etc/systemd/system/multi-user.target.wants/docker-storage-setup.service /root
    systemctl daemon-reload
}

#
# --- OpenShift Auxiliary Service Containers
#

function start_heat_agent_container() {
    # HEAT_AGENT_CONTAINER_IMAGE=$1
    docker pull $1 ||
        notify_failure "failed to pull heat agent docker image: $1"
    docker run \
           --name heat-agent \
           --detach \
           --privileged \
           --ipc=host \
           --net=host \
           --pid=host \
           -e HOST=/host \
           -e NAME=rhel-tools \
           --volume /run:/run \
           --volume /var/log:/var/log \
           --volume /etc/localtime:/etc/localtime \
           --volume ~/.ssh:/root/.ssh \
           --volume /:/host \
           --volume /etc/ansible:/etc/ansible \
           --volume /var/lib/heat-cfntools:/var/lib/heat-cfntools \
           --volume /var/lib/os-apply-config:/var/lib/os-apply-config \
           $1 ||
        notify_failure "failed to run heat-agent docker image: $1"
}

# ----------------------------------------------------------------------------
# Functions for RPM based systems
# ----------------------------------------------------------------------------

function verify_os_collect_config_is_installed() {
    systemctl is-enabled os-collect-config ||
        notify_failure "os-collect-config service is not installed or enabled"
}

function install_epel_repos_disabled() {
    # EPEL_RELEASE=$1 - hyphen delimiter
    # NOTE: install the right Ansible version on RHEL7.1 and Centos 7.1:
    local EPEL_REPO_URL=http://dl.fedoraproject.org/pub/epel/7/x86_64
    if ! rpm -q epel-release-$1
    then
        yum -y install \
            ${EPEL_REPO_URL}/e/epel-release-$1.noarch.rpm ||
            echo "Failed to find epel-release-$1.  Installing epel-release-latest-7."
    fi

    # If it fails, get the latest
    if ! rpm -q epel-release-$1
    then
        yum -y install \
            https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm ||
            notify_failure "could not install EPEL release $1 NOR the latest."
    fi
    sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo
}

#
# Check out the Ansible playbooks from a Git repository
#
function clone_openshift_ansible() {
    # GIT_URL=$1
    # GIT_REV=$2
    git clone "$1" /usr/share/ansible/openshift-ansible \
            || notify_failure "could not clone openshift-ansible: $1"
    cd /usr/share/ansible/openshift-ansible
    git checkout "$2" ||
        notify_failure "could not check out openshift-ansible rev $2"
}

# Do not update resolv.conf from eth0 when the system boots
disable_resolv_updates eth0

sudo_enable_from_ssh

if is_atomic_host
then
    systemd_docker_disable_storage_setup

    docker_set_storage_device $VOLUME_ID

    systemctl enable lvm2-lvmetad
    systemctl start lvm2-lvmetad

    docker-storage-setup || notify_failure "docker storage setup failed"

    systemctl start docker --ignore-dependencies ||
        notify_failure "docker service failed to start"

    start_heat_agent_container $HEAT_AGENT_CONTAINER_IMAGE

else
    verify_os_collect_config_is_installed

    yum -y install git httpd-tools ||
        notify_failure "could not install httpd-tools"

    # ensure openssl is installed on CentOS
    yum -y install pyOpenSSL ||
        notify_failure "could not install pyOpenSSL"

    if ! yum info ansible; then
        # Install the EPEL repository, but leave it disabled
        # Used only to install Ansible
        install_epel_repos_disabled $EPEL_RELEASE_VERSION

        # Install from the EPEL repository
        retry yum -y --enablerepo=epel install ansible ||
            notify_failure "could not install ansible"
    else
        retry yum -y install ansible
    fi

    if [ -n "$OPENSHIFT_ANSIBLE_GIT_URL" -a -n "$OPENSHIFT_ANSIBLE_GIT_REV" ]
    then
        clone_openshift_ansible \
            $OPENSHIFT_ANSIBLE_GIT_URL \
            $OPENSHIFT_ANSIBLE_GIT_REV
    else
        yum -y install openshift-ansible-roles openshift-ansible-playbooks \
            || notify_failure "could not install openshift-ansible"
    fi
fi

notify_success "OpenShift node has been prepared for running ansible."
