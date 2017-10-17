#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

ANSDIR=/var/lib/ansible
INVENTORY=$ANSDIR/inventory
NODESFILE=$ANSDIR/node_list

function get_new_nodes() {
    # compare old and new list of nodes and return all newly added nodes
    # separated by comma instead of newline
    if [ -e ${ANSDIR}.deployed ]; then
        str=$(comm -13 <(sort ${ANSDIR}.deployed/node_list) <(sort ${ANSDIR}/node_list) | sed ':a;N;$!ba;s/\n/","/g')
        [ -z "$str" ] && echo '' || echo "\"$str\""
    else
        echo ''
    fi
}

function create_metadata_json() {
    # $1 - metadata filename
    infra_arr=($all_infra_nodes)
    infra_count=${#infra_arr[@]}
    master_arr=($all_master_nodes)
    master_count=${#master_arr[@]}
    new_nodes=$(get_new_nodes)
    if [ -n "$os_username" ] && [ -n "$os_password" ] && \
            [ -n "$os_auth_url" ] && [ -n "$os_tenant_name" ]; then
        openstack_cloud_provider=true
    else
        openstack_cloud_provider=false
    fi
    deploy_router_or_registry=$([ "$deploy_router" == "True" -o \
        "$deploy_registry" == "True" ] && echo true || echo false)

    cat << EOF > $1
{
    "openshift_use_openshift_sdn": $([ "$openshift_sdn" == "openshift-sdn" ] && echo true || echo false),
    "openshift_use_flannel": $([ "$openshift_sdn" == "flannel" ] && echo true || echo false),
    "master_ha": $([ "$lb_type" != "none" -a $master_count -gt 1 ] && echo true || echo false),
    "master_ip": "$master_ip",
    "openstack_cloud_provider": $openstack_cloud_provider,
    "os_username":"$os_username",
    "os_password":"$os_password",
    "os_auth_url":"$os_auth_url",
    "os_tenant_name":"$os_tenant_name",
    "os_region_name":"$os_region_name",
    "os_domain_name":"$os_domain_name",
    "dedicated_lb": $([ "$lb_type" == "dedicated" ] && echo true || echo false),
    "no_lb": $([ "$lb_type" == "none" ] && echo true || echo false),
    "external_lb": $([ "$lb_type" == "external" ] && echo true || echo false),
    "masters": ["$(echo "$all_master_nodes" | sed 's/ /","/g')"],
    "infra_nodes": ["$(echo "$all_infra_nodes" | sed 's/ /","/g')"],
    "infra_count": $infra_count,
    "nodes": ["$(sed ':a;N;$!ba;s/\n/","/g' $NODESFILE)"],
    "new_nodes": [$new_nodes],
    "deploy_router_or_registry": $deploy_router_or_registry,
    "domainname": "$domainname",
    "app_subdomain": "${app_subdomain:-"cloudapps.$domainname"}",
    "lb_hostname": "$lb_hostname",
    "short_lb_hostname": "${lb_hostname%%.$domainname}",
    "deploy_router": $([ "$deploy_router" == "True" ] && echo true || echo false),
    "deploy_registry": $([ "$deploy_registry" == "True" ] && echo true || echo false),
    "registry_volume_fs": "$registry_volume_fs",
    "registry_volume_id": "$registry_volume_id",
    "registry_volume_size": "$registry_volume_size",
    "prepare_registry": $([ "$prepare_registry" == "True" ] && echo true || echo false),
    "heat_outputs_path": "$heat_outputs_path",
    "ssh_user": "$ssh_user",
    "deployment_type": "$deployment_type",
    "lb_ip": "$lb_ip",
    "dns_forwarders": "$dns_forwarders",
    "ldap_url": "$ldap_url",
    "ldap_bind_dn": "$ldap_bind_dn",
    "ldap_bind_password": "$ldap_bind_password",
    "ldap_ca": "$ldap_ca",
    "ldap_insecure": "$ldap_insecure",
    "ldap_url": "$ldap_url",
    "ldap_preferred_username": "$ldap_preferred_username",
    "bastion_instance_id": "$bastion_instance_id",
    "ansible_first_run": $([ -e ${ANSDIR}.deployed ] && echo false || echo true),
    "router_vip": "$router_vip",
    "volume_quota": $volume_quota
}
EOF
}

function create_global_vars() {
    if [ -n "$extra_openshift_ansible_params" ]; then
        cat << EOF > /tmp/extra_openshift_ansible_params.json
$extra_openshift_ansible_params
EOF
        /usr/local/bin/merge_dict /tmp/extra_openshift_ansible_params.json \
            /var/lib/ansible/group_vars/OSv3.yml
        rm /tmp/extra_openshift_ansible_params.json
    fi
}

function create_master_node_vars() {
    # $1 - node name
    if [ "$lb_type" == "none" ]; then
        public_name="$1.$domainname"
    else
        public_name="$lb_hostname"
    fi

    cat << EOF > /var/lib/ansible/host_vars/$1.$domainname.yml
openshift_hostname: $1.$domainname
openshift_public_hostname: $public_name
openshift_master_public_console_url: https://$public_name:8443/console
openshift_master_public_api_url: https://$public_name:8443
EOF
}

function create_openshift_node_vars() {
    # $1 - node name
    cat << EOF > /var/lib/ansible/host_vars/$1.yml
openshift_hostname: $1
openshift_public_hostname: $1
EOF
}

function is_scaleup() {
    # check if there are only new openshift nodes added - then we can play the
    # scaleup playbook, otherwise we run the main playbook
    [ -e ${ANSDIR}.deployed ] || return 1
    # check if diff between old and new inventory file contains only
    # node changes (ignore 'new_nodes' changes because nodes
    # are removed from [new_nodes] on the next stack-update run
    # NOTE: disable pipefail or it will always return 0.
    (set +o pipefail;
     diff $ANSDIR/inventory ${ANSDIR}.deployed/inventory | grep '^[<>]' |
        grep -v new_nodes | grep -v '[<>] $' |
        grep -v '.*-node') && return 1 || return 0
}

function backup_ansdir() {
    [ -e ${ANSDIR}.deployed ] && rm -rf ${ANSDIR}.deployed
    mv ${ANSDIR}.started ${ANSDIR}.deployed
}

[ "$prepare_ansible" == "False" ] && exit 0

mkdir -p /var/lib/ansible/group_vars
mkdir -p /var/lib/ansible/host_vars

touch $NODESFILE

existing=$(wc -l < $NODESFILE)
if [ -e /var/lib/ansible/node_count ]; then
    node_count=$(cat /var/lib/ansible/node_count)
    if [ $existing -lt $node_count -a "$autoscaling" != "True" ]; then
        echo "skipping ansible run - only $existing of $node_count is registered"
        exit 0
    fi
fi

create_metadata_json /var/lib/ansible/metadata.json

# generate ansible files from templates (located
# in /var/lib/os-apply-config/templates/)
os-apply-config -m /var/lib/ansible/metadata.json -t /var/lib/os-apply-config/templates

for node in $all_master_nodes; do
    create_master_node_vars $node
done

for node in $all_infra_nodes; do
    create_openshift_node_vars $node.$domainname
done

for node in `cat $NODESFILE`; do
    create_openshift_node_vars $node
done

create_global_vars

while pidof -x /bin/ansible-playbook /usr/bin/ansible-playbook; do
  echo "waiting for another ansible-playbook to finish"
  sleep 10
done

if [ -e ${ANSDIR}.deployed ] &&
        diff $ANSDIR/inventory ${ANSDIR}.deployed/inventory; then
    echo "inventory file has not changed since last ansible run, no need to re-run"
    exit 0
fi

[ -e ${ANSDIR}.started ] && rm -rf ${ANSDIR}.started
cp -a ${ANSDIR} ${ANSDIR}.started

# crond was stopped in cloud-init before yum update, make sure it's running
systemctl status crond && systemctl restart crond

export HOME=/root
export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles:/var/lib/ansible/roles
export ANSIBLE_HOST_KEY_CHECKING=False

logfile=/var/log/ansible.$$
if is_scaleup; then
    if [ -z $(get_new_nodes) ]; then
        echo "There are no new nodes, not running scalup playbook"
        backup_ansdir
        exit 0
    fi
    cmd="ansible-playbook -vvvv --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/playbooks/scaleup.yml"
else
    cmd="ansible-playbook -vvvv --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/playbooks/main.yml"
fi

if [ "$execute_ansible" == True ] ; then
    if ! $cmd > $logfile 2>&1; then
        tail -20 $logfile >&2
        echo "Failed to run '$cmd', full log is in $(hostname):$logfile" >&2
        exit 1
    else
        backup_ansdir
    fi
else
    echo "INFO: ansible execution disabled"
    echo "INFO: command = $cmd"
fi
