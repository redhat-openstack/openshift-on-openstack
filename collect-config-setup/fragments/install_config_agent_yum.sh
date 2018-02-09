#!/bin/bash
set -eux

# OSP_VERSION is set by ENV or by heat string replacement
[ -n "$OSP_VERSION" ] || (echo "Missing required value OSP_VERSION" ; exit 1)

# on Atomic host os-collect-config runs inside a container which is
# fetched&started in another step
[ -e /run/ostree-booted ] && exit 0

if ! yum info os-collect-config; then
    # if os-collect-config package is not available, first check if
    # the repo is available but disabled, otherwise install the package
    # from centos or rdoproject
    if yum repolist disabled|grep rhel-7-server-openstack-$OSP_VERSION-rpms; then
        subscription-manager repos --enable="rhel-7-server-openstack-$OSP_VERSION-rpms"
        if [ "$OSP_VERSION" -lt 10 ] ; then
            subscription-manager repos --enable="rhel-7-server-openstack-$OSP_VERSION-director-rpms"
        fi
    elif yum info centos-release-openstack-liberty; then
        yum -y install centos-release-openstack-liberty
    else
        yum -y install https://rdoproject.org/repos/openstack-pike/rdo-release-pike.rpm
    fi
fi
yum -y install os-collect-config python-zaqarclient os-refresh-config os-apply-config openstack-heat-templates python-oslo-log python-psutil openstack-heat-agents
#yum-config-manager --disable 'epel*'
