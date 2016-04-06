#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

INVENTORY=/var/lib/ansible/inventory
NODESFILE=/var/lib/ansible/openshift_nodes

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
    "dedicated_lb": $([ "$lb_type" == "dedicated" ] && echo true || echo false),
    "masters": ["$(echo "$all_master_nodes" | sed 's/ /","/g')"],
    "master_count": $master_count,
    "nodes": ["$(sed ':a;N;$!ba;s/\n/","/g' $NODESFILE)"],
    "deploy_router_or_registry": $deploy_router_or_registry,
    "domainname": "$domainname",
    "lb_hostname": "$lb_hostname",
    "deploy_router": "$deploy_router",
    "deploy_registry": "$deploy_registry",
    "heat_outputs_path": "$heat_outputs_path",
    "ssh_user": "$ssh_user",
    "deployment_type": "$deployment_type",
    "ldap_url": "$ldap_url",
    "ldap_bind_dn": "$ldap_bind_dn",
    "ldap_bind_password": "$ldap_bind_password",
    "ldap_ca": "$ldap_ca",
    "ldap_insecure": "$ldap_insecure",
    "ldap_url": "$ldap_url",
    "ldap_preferred_username": "$ldap_preferred_username"
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

# crond was stopped in cloud-init before yum update, make sure it's running
systemctl status crond && systemctl restart crond

[ "$skip_ansible" == "True" ] && exit 0

mkdir -p /var/lib/ansible/group_vars
mkdir -p /var/lib/ansible/host_vars

touch $NODESFILE
grep -q "$node_hostname" $NODESFILE || echo $node_hostname >> $NODESFILE

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

while pidof -x /bin/ansible-playbook; do
  echo "waiting for another ansible-playbook to finish"
  sleep 10
done

if [ -e ${INVENTORY}.deployed ] &&
        diff $INVENTORY ${INVENTORY}.deployed; then
    echo "inventory file has not changed since last ansible run, no need to re-run"
    exit 0
fi

cp /var/lib/ansible/inventory /var/lib/ansible/inventory.started

export HOME=/root
export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles
export ANSIBLE_HOST_KEY_CHECKING=False

# Export Openstack environment variables
export OS_USERNAME=$os_username
export OS_PASSWORD=$os_password
export OS_AUTH_URL=$os_auth_url
export OS_TENANT_NAME=$os_tenant_name
export OS_REGION_NAME=$os_region_name

if [ "$deploy_registry" == "True" ]; then
    # To make the stats port acessible publicly, we will need to open
    # it on your master
    iptables -I OS_FIREWALL_ALLOW -p tcp -m tcp --dport 1936 -j ACCEPT
    service iptables save || true; service iptables restart || true
fi

ansible-playbook --inventory /var/lib/ansible/inventory \
    /var/lib/ansible/playbooks/main.yml > /var/log/ansible.$$ 2>&1

mv /var/lib/ansible/inventory.started /var/lib/ansible/inventory.deployed
