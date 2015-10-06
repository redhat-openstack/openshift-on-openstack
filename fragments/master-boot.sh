#!/bin/bash

set -eu
set -x
set -o pipefail

# Set the DNS to the one provided
sed -i 's/search openstacklocal/&\nnameserver $DNS_IP/' /etc/resolv.conf

# master and nodes
retry yum install -y deltarpm
retry yum -y update

# master
retry yum install -y git httpd-tools

# TODO; Docker 1.6.2-14 is now in the repos, just do `yum install docker` here
# Centos 7.1: We need docker >= 1.6.2
retry yum install -y http://cbs.centos.org/kojifiles/packages/docker/1.6.2/4.gitc3ca5bb.el7/x86_64/docker-1.6.2-4.gitc3ca5bb.el7.x86_64.rpm
echo "INSECURE_REGISTRY='--insecure-registry 0.0.0.0/0'" >> /etc/sysconfig/docker
systemctl enable docker

# NOTE: install the right Ansible version on RHEL7.1 and Centos 7.1:
retry yum -y install \
    http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo
retry yum -y --enablerepo=epel install ansible


git clone "$OPENSHIFT_ANSIBLE_GIT_URL" openshift-ansible
cd openshift-ansible
git checkout "$OPENSHIFT_ANSIBLE_GIT_REV"

# NOTE: the first ansible run hangs during the "Start and enable iptables
# service" task. Doing it explicitly seems to fix that:
yum install -y iptables iptables-services
systemctl enable iptables
systemctl restart iptables

# NOTE: Ignore the known_hosts check/propmt for now:
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook --inventory /var/lib/ansible-inventory playbooks/byo/config.yml

ansible -i /var/lib/ansible-inventory all -a 'docker-bridge-setup'

echo "OpenShift has been installed."
