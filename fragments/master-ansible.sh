#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

# master and nodes
# crond was stopped in cloud-init before yum update, make sure it's running
systemctl status crond && systemctl restart crond


echo $NODE_HOSTNAME >> /var/lib/openshift_nodes

export HOME=/root
export ANSIBLE_ROLES_PATH=/usr/share/ansible/openshift-ansible/roles

case "$OPENSHIFT_SDN" in
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
ansible_ssh_user: $SSH_USER
ansible_sudo: true
deployment_type: $DEPLOYMENT_TYPE # deployment type valid values are origin, online and openshif-enterprise
osm_default_subdomain: cloudapps.$DOMAINNAME # default subdomain to use for exposed routes
EOF

if [ -n "$LB_HOSTNAME" ]; then
    LB_CHILDREN=lb
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_cluster_password: openshift_cluster
openshift_master_cluster_method: native
openshift_master_cluster_hostname: $LB_HOSTNAME.$DOMAINNAME
openshift_master_cluster_public_hostname: $LB_HOSTNAME.$DOMAINNAME
EOF
else
    LB_CHILDREN=''
fi

if [ -n "$LDAP_URL" ]; then
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_identity_providers:
  - name: ldap_auth
    kind: LDAPPasswordIdentityProvider
    challenge: true
    login: true
    bindDN: $LDAP_BIND_DN
    bindPassword: $LDAP_BIND_PASSWORD
    ca: '$LDAP_CA'
    insecure: $LDAP_INSECURE
    url: $LDAP_URL
    attributes:
      id: ['dn']
      email: ['mail']
      name: ['cn']
      preferredUsername: ['$LDAP_PREFERRED_USERNAME']
EOF
else
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_identity_providers:
  - name: htpasswd_auth
    login: true
    challenge: true
    kind: HTPasswdPasswordIdentityProvider
    filename: /etc/openshift/openshift-passwd
openshift_use_openshift_sdn: $openshift_use_openshift_sdn
openshift_use_flannel: $openshift_use_flannel
EOF
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
$LB_CHILDREN

[masters]
EOF

num_infra=0
for node in $ALL_MASTER_NODES
do
    num_infra=$((num_infra+1))

    if [ -n "$LB_HOSTNAME" ]
    then
        public_name="$LB_HOSTNAME.$DOMAINNAME"
    else
        public_name="$node.$DOMAINNAME"
    fi

    # Set variables for master node
    cat << EOF > /var/lib/ansible/host_vars/$node.$DOMAINNAME.yml
openshift_hostname: $node.$DOMAINNAME
openshift_public_hostname: $public_name
openshift_master_public_console_url: https://$public_name:8443/console
openshift_master_public_api_url: https://$public_name:8443
openshift_schedulable: true
openshift_node_labels:
  region: infra
  zone: default
EOF
    echo -e "$node.$DOMAINNAME" >> /var/lib/ansible/inventory
done

echo -e "\n[etcd]" >> /var/lib/ansible/inventory
for node in $ALL_MASTER_NODES; do
    echo "$node.$DOMAINNAME" >> /var/lib/ansible/inventory
done

# host group for nodes
echo -e "\n[nodes]" >> /var/lib/ansible/inventory
for node in $ALL_MASTER_NODES;do
    echo "$node.$DOMAINNAME" >> /var/lib/ansible/inventory
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

if [ -n "$LB_HOSTNAME" ]; then
    cat << EOF >> /var/lib/ansible/inventory
[lb]
$LB_HOSTNAME.$DOMAINNAME
EOF
fi

while pidof -x /bin/ansible-playbook; do
  echo "waiting for another ansible-playbook to finish"
  sleep 10
done

if [ -e /var/lib/ansible/inventory.deployed ] && diff /var/lib/ansible/inventory /var/lib/ansible/inventory.deployed; then
    echo "inventory file has not changed since last ansible run, no need to re-run"
    exit 0
fi

cp /var/lib/ansible/inventory /var/lib/ansible/inventory.started

# NOTE: docker-storage-setup hangs during cloud-init because systemd file is set
# to run after cloud-final.  Temporarily move out of the way (as we've already done storage setup
if [ -e /usr/lib/systemd/system/docker-storage-setup.service ]; then
    mv /usr/lib/systemd/system/docker-storage-setup.service $HOME
    systemctl daemon-reload
fi

# NOTE: Ignore the known_hosts check/propmt for now:
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook --inventory /var/lib/ansible/inventory /usr/share/ansible/openshift-ansible/playbooks/byo/config.yml > /var/log/ansible.$$ 2>&1

# Deploy registry and/or router
if [ "$DEPLOY_ROUTER" == "True" ] || [ "$DEPLOY_REGISTRY" == "True" ]; then
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

    echo "num_infra: $num_infra" >> /var/lib/ansible/group_vars/masters.yml

    if [ "$DEPLOY_REGISTRY" == "True" ]; then
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

    if [ "$DEPLOY_ROUTER" == "True" ]; then
        echo "openshift_router_selector: region=infra" >> /var/lib/ansible/group_vars/masters.yml
        cat << EOF >> /var/lib/ansible/services.yml
- name: Create router
  hosts: oo_first_master
  roles:
  - role: openshift_router
    when: openshift.master.infra_nodes is defined
EOF
    fi

    ansible-playbook --inventory /var/lib/ansible/inventory /var/lib/ansible/services.yml

    # Give a little time to Openshift to schedule the registry and/or the router
    sleep 180
fi

for node in $ALL_MASTER_NODES;do
    oadm manage-node $node.$DOMAINNAME --schedulable=false || true
done

# Move docker-storage-setup unit file back in place
mv $HOME/docker-storage-setup.service /usr/lib/systemd/system
systemctl daemon-reload

mv /var/lib/ansible/inventory.started /var/lib/ansible/inventory.deployed
