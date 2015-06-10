#!/bin/bash

set -eu
set -o pipefail

cd /root/
git clone https://github.com/openshift/openshift-ansible.git
cd openshift-ansible

# NOTE: Ignore the known_hosts check/propmt for now:
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook --inventory /var/lib/ansible-inventory playbooks/byo/config.yml
