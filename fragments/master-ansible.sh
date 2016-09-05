#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

INVENTORY=/var/lib/ansible/inventory
NODESFILE=/var/lib/ansible/node_list

function create_metadata_json() {
    # $1 - metadata filename
    master_arr=($all_master_nodes)
    master_count=${#master_arr[@]}
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
    "openstack_cloud_provider": $openstack_cloud_provider,
    "os_username":"$os_username",
    "os_password":"$os_password",
    "os_auth_url":"$os_auth_url",
    "os_tenant_name":"$os_tenant_name",
    "os_region_name":"$os_region_name",
    "dedicated_lb": $([ "$lb_type" == "dedicated" ] && echo true || echo false),
    "no_lb": $([ "$lb_type" == "none" -o "$lb_type" == "external" ] && echo true || echo false),
    "masters": ["$(echo "$all_master_nodes" | sed 's/ /","/g')"],
    "master_count": $master_count,
    "nodes": ["$(sed ':a;N;$!ba;s/\n/","/g' $NODESFILE)"],
    "deploy_router_or_registry": $deploy_router_or_registry,
    "domainname": "$domainname",
    "lb_hostname": "$lb_hostname",
    "deploy_router": $([ "$deploy_router" == "True" ] && echo true || echo false),
    "deploy_registry": $([ "$deploy_registry" == "True" ] && echo true || echo false),
    "registry_volume_fs": "$registry_volume_fs",
    "registry_volume_id": "$registry_volume_id",
    "prepare_registry": "$prepare_registry",
    "heat_outputs_path": "$heat_outputs_path",
    "ssh_user": "$ssh_user",
    "deployment_type": "$deployment_type",
    "skip_dns": $([ "$skip_dns" == "True" ] && echo true || echo false),
    "lb_ip": "$lb_ip",
    "dns_forwarders": "$dns_forwarders",
    "dns_ip": "$dns_ip",
    "ldap_url": "$ldap_url",
    "ldap_bind_dn": "$ldap_bind_dn",
    "ldap_bind_password": "$ldap_bind_password",
    "ldap_ca": "$ldap_ca",
    "ldap_insecure": "$ldap_insecure",
    "ldap_url": "$ldap_url",
    "ldap_preferred_username": "$ldap_preferred_username",
    "infra_instance_id": "$infra_instance_id",
    "ansible_first_run": $([ -e ${INVENTORY}.deployed ] && echo false || echo true),
    "router_vip": "$router_vip",
    "volume_quota": $volume_quota
}
EOF
}

function create_master_node_vars() {
    # $1 - node name
    if [ "$lb_type" == "none" ]; then
        public_name="$1.$domainname"
    else
        public_name="$lb_hostname.$domainname"
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
    [ -e ${INVENTORY}.deployed ] || return 1
    (diff $INVENTORY ${INVENTORY}.deployed |
        grep '^[<>]' | grep -v '^< .*-node') && return 1 || return 0
}

[ "$skip_ansible" == "True" ] && exit 0

mkdir -p /var/lib/ansible/group_vars
mkdir -p /var/lib/ansible/host_vars

touch $NODESFILE

create_metadata_json /var/lib/ansible/metadata.json

# generate ansible files from templates (located
# in /var/lib/os-apply-config/templates/)
os-apply-config -m /var/lib/ansible/metadata.json -t /var/lib/os-apply-config/templates

for node in $all_master_nodes; do
    create_master_node_vars $node
done

for node in `cat $NODESFILE`; do
    create_openshift_node_vars $node
done

while pidof -x /bin/ansible-playbook /usr/bin/ansible-playbook; do
  echo "waiting for another ansible-playbook to finish"
  sleep 10
done

if [ -e ${INVENTORY}.deployed ] &&
        diff $INVENTORY ${INVENTORY}.deployed; then
    echo "inventory file has not changed since last ansible run, no need to re-run"
    exit 0
fi

cp ${INVENTORY} ${INVENTORY}.started

# crond was stopped in cloud-init before yum update, make sure it's running
systemctl status crond && systemctl restart crond

export HOME=/root
export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles:/var/lib/ansible/roles
export ANSIBLE_HOST_KEY_CHECKING=False

logfile=/var/log/ansible.$$
if is_scaleup; then
    cmd="ansible-playbook -vvvv --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/playbooks/scaleup.yml"
else
    cmd="ansible-playbook -vvvv --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/playbooks/main.yml"
fi

if ! $cmd > $logfile 2>&1; then
    tail -20 $logfile >&2
    echo "Failed to run '$cmd', full log is in $(hostname):$logfile" >&2
    exit 1
else
    mv ${INVENTORY}.started ${INVENTORY}.deployed
fi
