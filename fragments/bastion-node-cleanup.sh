#!/bin/bash
# ENVVARS
#   node_name = "<hostname>"

# Exit on fail or bad VAR expansion
set -eux

# ============================================================================
# MAIN
# ============================================================================

# used by ansible for setting ControlPath ssh param
export HOME=/root

INVENTORY=/var/lib/ansible/inventory

# evacuate all the pods and remove the node from the openshift service
# using the first master
if [ -e $INVENTORY -a "$node_type" == node ]; then
    export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles
    export ANSIBLE_HOST_KEY_CHECKING=False

    ansible-playbook -vvvv -e node=$node_name \
        --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/playbooks/scaledown.yml &>> /var/log/ansible-scaledown.$$ || true
fi

# remove from the local list
NODESFILE=/var/lib/ansible/${node_type}_list
if [ -e $NODESFILE ]; then
    cp $NODESFILE{,.bkp}
    grep -v "$node_name" ${NODESFILE}.bkp > $NODESFILE || true
fi

# unregister the node if registered with subscription-manager
[ -e $INVENTORY ] && ansible $node_name -m shell \
        -u $ssh_user --sudo -i $INVENTORY \
        -a "subscription-manager unregister && subscription-manager clean" || true

echo "Deleted node $node_name"
