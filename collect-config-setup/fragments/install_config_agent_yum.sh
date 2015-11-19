#!/bin/bash
set -eux

yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum -y install https://repos.fedorapeople.org/repos/openstack/openstack-kilo/rdo-release-kilo-1.noarch.rpm
yum -y install os-collect-config python-zaqarclient os-refresh-config os-apply-config
#yum-config-manager --disable 'epel*'
