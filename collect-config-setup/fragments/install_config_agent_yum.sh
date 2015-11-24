#!/bin/bash
set -eux

if ! yum info os-collect-config; then
    # if os-collect-config package is not available, first check if
    # the repo is available but disabled, otherwise install the package
    # from epel
    if yum repolist disabled|grep rhel-7-server-openstack-7.0-director-rpms; then
        subscription-manager repos --enable="rhel-7-server-openstack-7.0-director-rpms"
        subscription-manager repos --enable="rhel-7-server-openstack-7.0-rpms"
    else
        # for now if os-collect-config is not available from any of existing
        # repositories, add tripleo's default repo which contains these packages:
        yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
        yum -y install https://repos.fedorapeople.org/repos/openstack/openstack-kilo/rdo-release-kilo-1.noarch.rpm
    fi
fi
yum -y install os-collect-config python-zaqarclient os-refresh-config os-apply-config
#yum-config-manager --disable 'epel*'
