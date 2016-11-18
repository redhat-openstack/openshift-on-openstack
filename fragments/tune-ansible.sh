#!/bin/bash
#
# set ansible configuration values to optimize ssh and fact gathering
#

# Exit on single command fail, or undefined variable reference
set -eux

# Return the last non-zero exit code from a pipe (or zero for success)
set -o pipefail

ANSIBLE_CFG=/etc/ansible/ansible.cfg

# Make a single change to the local Ansible configuration file
function set_ansible_configuration() {
    # SECTION=$1
    # OPTION=$2
    # VALUE=$3

    # Run a local command to modify the ansible configuration itself
    ansible all --connection=local -i "localhost," -m ini_file \
      -a "dest=${ANSIBLE_CFG} section='$1' option='$2' value='$3' state=present"
}

# ============================================================================
# MAIN
# ============================================================================

# Enable re-use of SSH connections
# http://docs.ansible.com/ansible/intro_configuration.html#pipelining
set_ansible_configuration ssh_connection "pipelining" "True"

# Extend the connection idle timeout to 10 minutes
# http://docs.ansible.com/ansible/intro_configuration.html#ssh-args
set_ansible_configuration ssh_connection "ssh_args" "-o ControlMaster=auto -o ControlPersist=600s"

# Shorten the socket path
# http://docs.ansible.com/ansible/intro_configuration.html#control-path
set_ansible_configuration ssh_connection "control_path" '%(directory)s/%%h-%%r'

# Force re-gather facts for each new play (execution)
# http://docs.ansible.com/ansible/intro_configuration.html#gathering
set_ansible_configuration defaults "gathering" "implicit"

# Cache facts in JSON format in a tmp dir and save them 10 minutes
# http://docs.ansible.com/ansible/playbooks_variables.html#fact-caching
set_ansible_configuration defaults \
                          "fact_caching_connection" \
                          "/tmp/ansible/facts"
set_ansible_configuration defaults "fact_caching_timeout" "600"
set_ansible_configuration defaults "fact_caching" "jsonfile"

#set_ansible_configuration defaults  "callback_plugins = /usr/lib/python2.7/site-packages/ara/plugins/callbacks:$VIRTUAL_ENV/lib/python2.7/site-packages/ara/plugins/callbacks:/usr/local/lib/python2.7/dist-packages/ara/plugins/callbacks"

#yum install -y python-pip gcc python-devel libffi-devel openssl-devel redhat-rpm-config
#pip install ara
