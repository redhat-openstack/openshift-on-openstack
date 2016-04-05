#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

# master and nodes
# crond was stopped in cloud-init before yum update, make sure it's running
systemctl status crond && systemctl restart crond

[ "$skip_ansible" == "True" ] && exit 0

echo $node_hostname >> /var/lib/openshift_nodes

export HOME=/root
export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles

case "$openshift_sdn" in
	openshift-sdn)
		openshift_use_openshift_sdn=true
		openshift_use_flannel=false
	;;
	flannel)
		openshift_use_openshift_sdn=false
		openshift_use_flannel=true
	;;
	none)
		openshift_use_openshift_sdn=false
		openshift_use_flannel=false
	;;
esac

mkdir -p /var/lib/ansible/group_vars
mkdir -p /var/lib/ansible/host_vars

# Set variables common for all OSEv3 hosts
cat << EOF > /var/lib/ansible/group_vars/OSv3.yml
ansible_ssh_user: $ssh_user
ansible_sudo: true
deployment_type: $deployment_type # deployment type valid values are origin, online and openshif-enterprise
osm_default_subdomain: cloudapps.$domainname # default subdomain to use for exposed routes
openshift_override_hostname_check: true
openshift_use_openshift_sdn: $openshift_use_openshift_sdn
openshift_use_flannel: $openshift_use_flannel
EOF

MASTER_ARR=($all_master_nodes)
MASTER_COUNT=${#MASTER_ARR[@]}
if [ "$lb_type" != "none" -a $MASTER_COUNT -gt 1 ]; then
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_cluster_password: openshift_cluster
openshift_master_cluster_method: native
openshift_master_cluster_hostname: $lb_hostname.$domainname
openshift_master_cluster_public_hostname: $lb_hostname.$domainname
EOF
fi

if [ -n "$ldap_url" ]; then
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_identity_providers:
  - name: ldap_auth
    kind: LDAPPasswordIdentityProvider
    challenge: true
    login: true
    bindDN: $ldap_bind_dn
    bindPassword: $ldap_bind_password
    ca: '$ldap_ca'
    insecure: $ldap_insecure
    url: $ldap_url
    attributes:
      id: ['dn']
      email: ['mail']
      name: ['cn']
      preferredUsername: ['$ldap_preferred_username']
EOF
else
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_identity_providers:
  - name: htpasswd_auth
    login: true
    challenge: true
    kind: HTPasswdPasswordIdentityProvider
    filename: /etc/origin/openshift-passwd
EOF
fi

if [ -n "$os_username" ] && [ -n "$os_password" ] && [ -n "$os_auth_url" ] && [ -n "$os_tenant_name" ]; then
    echo "openshift_cloud_provider: openstack" >> /var/lib/ansible/group_vars/OSv3.yml
fi

# Set variables common for all nodes
cat << EOF > /var/lib/ansible/group_vars/nodes.yml
openshift_node_labels:
  region: primary
  zone: default
EOF

# Write ansible inventory
cat << EOF > /var/lib/ansible/inventory
# Create an OSEv3 group that contains the masters and nodes groups
[OSv3:children]
masters
nodes
etcd
EOF

# if we deploy a loadbalancer node, add 'lb' group
[ "$lb_type" == "dedicated" ] && echo -e "lb" >> /var/lib/ansible/inventory

echo -e "\n[masters]" >> /var/lib/ansible/inventory
for node in $all_master_nodes
do
    if [ "$lb_type" == "none" ]; then
        public_name="$node.$domainname"
    else
        public_name="$lb_hostname.$domainname"
    fi

    # Set variables for master node
    cat << EOF > /var/lib/ansible/host_vars/$node.$domainname.yml
openshift_hostname: $node.$domainname
openshift_public_hostname: $public_name
openshift_master_public_console_url: https://$public_name:8443/console
openshift_master_public_api_url: https://$public_name:8443
openshift_schedulable: true
openshift_node_labels:
  region: infra
  zone: default
EOF
    echo -e "$node.$domainname" >> /var/lib/ansible/inventory
done

echo -e "\n[etcd]" >> /var/lib/ansible/inventory
for node in $all_master_nodes; do
    echo "$node.$domainname" >> /var/lib/ansible/inventory
done


[ "$lb_type" == "dedicated" ] && echo -e "\n[lb]\n$lb_hostname.$domainname" >> /var/lib/ansible/inventory

# host group for nodes
echo -e "\n[nodes]" >> /var/lib/ansible/inventory
for node in $all_master_nodes;do
    echo "$node.$domainname" >> /var/lib/ansible/inventory
done

# this script is triggered for each node being added, let's
# give all nodes some time to write their hostnames into the list (this
# minimizes number of ansible-playbook re-runs)
sleep 60

### Note - openshift_hostname and openshift_public_hostname are overrides used because OpenStack instance metadata appends .novalocal by default to hostnames

# Write each node
for node in `cat /var/lib/openshift_nodes`; do
  echo "$node" >> /var/lib/ansible/inventory
  echo -e "openshift_hostname: $node\nopenshift_public_hostname: $node" >> /var/lib/ansible/host_vars/$node
done

while pidof -x /bin/ansible-playbook; do
  echo "waiting for another ansible-playbook to finish"
  sleep 10
done

if [ -e /var/lib/ansible/inventory.deployed ] && diff /var/lib/ansible/inventory /var/lib/ansible/inventory.deployed; then
    echo "inventory file has not changed since last ansible run, no need to re-run"
    exit 0
fi

cp /var/lib/ansible/inventory /var/lib/ansible/inventory.started

# Export Openstack environment variables
export OS_USERNAME=$os_username
export OS_PASSWORD=$os_password
export OS_AUTH_URL=$os_auth_url
export OS_TENANT_NAME=$os_tenant_name
export OS_REGION_NAME=$os_region_name

# NOTE: Ignore the known_hosts check/propmt for now:
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook \
    -vvvv \
    --inventory /var/lib/ansible/inventory \
    /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml \
    > /var/log/ansible.$$ 2>&1

# Deploy registry and/or router
if [ "$deploy_router" == "True" ] || [ "$deploy_registry" == "True" ]; then
    cat << EOF > /var/lib/ansible/services.yml
---
- include: /usr/share/ansible/openshift-ansible/playbooks/common/openshift-cluster/evaluate_groups.yml
  vars:
    g_etcd_hosts: "{{ groups.etcd | default([]) }}"
    g_lb_hosts: "{{ groups.lb | default([]) }}"
    g_master_hosts: "{{ groups.masters | default([]) }}"
    g_node_hosts: "{{ groups.nodes | default([]) }}"
    g_nfs_hosts: "{{ groups.nfs | default([]) }}"
    g_etcd_group: "{{ 'etcd' }}"
    g_masters_group: "{{ 'masters' }}"
    g_nodes_group: "{{ 'nodes' }}"
    g_lb_group: "{{ 'lb' }}"
    openshift_cluster_id: "{{ cluster_id | default('default') }}"
    openshift_debug_level: 2
    openshift_deployment_type: "{{ deployment_type }}"

- name: Set facts
  hosts: oo_first_master
  roles:
  - openshift_facts
  post_tasks:
  - openshift_facts:
      role: "{{ item.role }}"
      local_facts: "{{ item.local_facts }}"
    with_items:
      - role: master
        local_facts:
          registry_selector: "{{ openshift_registry_selector | default(None) }}"
          infra_nodes: "{{ num_infra | default(None) }}"
EOF

    echo "num_infra: $MASTER_COUNT" >> /var/lib/ansible/group_vars/masters.yml

    if [ "$deploy_registry" == "True" ]; then
        echo "openshift_registry_selector: region=infra" >> /var/lib/ansible/group_vars/masters.yml
        cat << EOF >> /var/lib/ansible/services.yml
- name: Create registry
  hosts: oo_first_master
  vars:
    attach_registry_volume: false
  roles:
  - role: openshift_registry
    when: openshift.master.infra_nodes is defined
EOF

        # To make the stats port acessible publicly, we will need to open it on your master
        iptables -I OS_FIREWALL_ALLOW -p tcp -m tcp --dport 1936 -j ACCEPT
        service iptables save || true; service iptables restart || true
    fi

    if [ "$deploy_router" == "True" ]; then
        echo "openshift_router_selector: region=infra" >> /var/lib/ansible/group_vars/masters.yml
        cat << EOF >> /var/lib/ansible/services.yml
- name: Create router
  hosts: oo_first_master
  roles:
  - role: openshift_router
    when: openshift.master.infra_nodes is defined
EOF
    fi

    ansible-playbook \
        --inventory /var/lib/ansible/inventory \
        /var/lib/ansible/services.yml \
        > /var/log/ansible-services-$$.log 2>&1

    # Give a little time to Openshift to schedule the registry and/or the router
    sleep 180
fi

ansible masters \
        -m shell \
        -a 'oadm manage-node $HOSTNAME --schedulable=false || true' \
        -u cloud-user --sudo \
        -i /var/lib/ansible/inventory \
        > /var/log/ansible-manage-node-$$.log 2>&1

mv /var/lib/ansible/inventory.started /var/lib/ansible/inventory.deployed

ansible masters[0] \
        -m fetch \
        -a "src=/etc/origin/master/ca.crt dest=$heat_outputs_path.ca_cert flat=yes" \
        -u cloud-user --sudo \
        -i /var/lib/ansible/inventory \
        > /var/log/ansible-fetch-ca-crt-$$.log 2>&1

ansible masters[0] \
        -m fetch \
        -a "src=/etc/origin/master/ca.key dest=$heat_outputs_path.ca_key flat=yes" \
        -u cloud-user --sudo \
        -i /var/lib/ansible/inventory \
        > /var/log/ansible-fetch-ca-key-$$.log 2>&1
