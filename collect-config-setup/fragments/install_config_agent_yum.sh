#!/bin/bash
set -eux

# on Atomic host os-collect-config runs inside a container which is
# fetched&started in another step
[ -e /run/ostree-booted ] && exit 0

if ! yum info os-collect-config; then
    # if os-collect-config package is not available, first check if
    # the repo is available but disabled, otherwise install the package
    # from epel
    if yum repolist disabled|grep rhel-7-server-openstack-8-director-rpms; then
        subscription-manager repos --enable="rhel-7-server-openstack-8-director-rpms"
        subscription-manager repos --enable="rhel-7-server-openstack-8-rpms"
    else
        yum -y install centos-release-openstack-liberty
    fi
fi
yum -y install os-collect-config python-zaqarclient os-refresh-config os-apply-config openstack-heat-templates python-oslo-log python-psutil
#yum-config-manager --disable 'epel*'
