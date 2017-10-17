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

    ansible-playbook -vvvv -e node=$node_name -e node_id=$node_id \
        --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/playbooks/scaledown.yml &>> /var/log/ansible-scaledown.$$ || true
fi

# remove from the local list
NODESFILE=/var/lib/ansible/${node_type}_list
if [ -e $NODESFILE ]; then
    cp $NODESFILE{,.bkp}
    grep -v "$node_name" ${NODESFILE}.bkp > $NODESFILE || true
fi

# unregister the node if 
# - node_id matches the one defined in deployment_bastion_node_cleanup
# - registered with subscription-manager
if [ -e $INVENTORY ]; then
    echo "Cleanup node $node_name with $node_id" >> /var/log/ansible-node-cleanup.log
    ansible $node_name -m shell \
        -u $ssh_user --sudo -i $INVENTORY \
        -a "test -d /var/lib/cloud/instances/$node_id && subscription-manager unregister && subscription-manager clean" || true
fi


echo "Deleted node $node_name with id $node_id"
