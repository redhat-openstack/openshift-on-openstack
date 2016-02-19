#!/bin/bash

set -eux
set -o pipefail

# Tune ansible configuration
function set_ansible_configuration() {
    ansible all --connection=local -i "localhost," -m ini_file -a "dest=/etc/ansible/ansible.cfg section='$1' option='$2' value='$3' state=present"
}

set_ansible_configuration ssh_connection "pipelining" "True"
set_ansible_configuration ssh_connection "ssh_args" "-o ControlMaster=auto -o ControlPersist=600s"
set_ansible_configuration ssh_connection "control_path" '%(directory)s/%%h-%%r'

set_ansible_configuration defaults "gathering" "implicit"
set_ansible_configuration defaults "fact_caching_connection" "/tmp/ansible/facts"
set_ansible_configuration defaults "fact_caching" "jsonfile"
set_ansible_configuration defaults "fact_caching_timeout" "600"
