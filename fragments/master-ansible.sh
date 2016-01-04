#!/bin/bash
# Create an Ansible inventory file if it doesn't already exist

set -eu
set -x
set -o pipefail

# master and nodes
# crond was stopped in cloud-init before yum update, make sure it's running
systemctl status crond && systemctl restart crond


echo $NODE_HOSTNAME >> /var/lib/openshift_nodes

if [ -n "$LB_HOSTNAME" ]; then
    LB_CHILDREN=lb
else
    LB_CHILDREN=''
fi

export HOME=/root

# Set variables common for all OSEv3 hosts
mkdir -p /var/lib/ansible/group_vars
cat << EOF > /var/lib/ansible/group_vars/OSv3.yml
ansible_ssh_user: $SSH_USER
ansible_sudo: true
deployment_type: $DEPLOYMENT_TYPE # deployment type valid values are origin, online and openshif-enterprise
osm_default_subdomain: cloudapps.$DOMAINNAME # default subdomain to use for exposed routes
EOF

if [ -n "$LB_HOSTNAME" ]; then
    cat << EOF >> /var/lib/ansible/group_vars/OSv3.yml
openshift_master_cluster_password: openshift_cluster
openshift_master_cluster_method: native
openshift_master_cluster_hostname: $LB_HOSTNAME.$DOMAINNAME
openshift_master_cluster_public_hostname: $LB_HOSTNAME.$DOMAINNAME

EOF
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
EOF
fi


cat << EOF > /var/lib/ansible/inventory
# Create an OSEv3 group that contains the masters and nodes groups
[OSv3:children]
masters
nodes
etcd
$LB_CHILDREN

### Note - openshift_hostname and openshift_public_hostname are overrides used because OpenStack instance metadata appends .novalocal by default to hostnames

EOF

if [ -n "$LB_HOSTNAME" ]; then
    cat << EOF >> /var/lib/ansible/inventory
[lb]
$LB_HOSTNAME.$DOMAINNAME
EOF
fi

echo -e "\n[masters]" >> /var/lib/ansible/inventory
for node in $ALL_MASTER_NODES;do
    if [ -n "$LB_HOSTNAME" ]; then
        public_name="$LB_HOSTNAME.$DOMAINNAME"
    else
        public_name="$node.$DOMAINNAME"
    fi
    echo "$node.$DOMAINNAME openshift_hostname=$node.$DOMAINNAME openshift_public_hostname=$public_name openshift_master_public_console_url=https://$public_name:8443/console openshift_master_public_api_url=https://$public_name:8443" >> /var/lib/ansible/inventory
done


echo -e "\n[etcd]" >> /var/lib/ansible/inventory
for node in $ALL_MASTER_NODES;do
    if [ -n "$LB_HOSTNAME" ]; then
        public_name="$LB_HOSTNAME.$DOMAINNAME"
    else
        public_name="$node.$DOMAINNAME"
    fi
    echo "$node.$DOMAINNAME openshift_hostname=$node.$DOMAINNAME openshift_public_hostname=$public_name" >> /var/lib/ansible/inventory
done

# host group for nodes
echo -e "\n[nodes]" >> /var/lib/ansible/inventory
for node in $ALL_MASTER_NODES;do
    echo "$node.$DOMAINNAME openshift_hostname=$node.$DOMAINNAME openshift_public_hostname=$node.$DOMAINNAME openshift_node_labels=\"{'region': 'infra', 'zone': 'default'}\"" >> /var/lib/ansible/inventory
done

# this script is triggered for each node being added, let's
# give all nodes some time to write their hostnames into the list (this
# minimizes number of ansible-playbook re-runs)
sleep 60

# Write each node
for node in `cat /var/lib/openshift_nodes`;do
  #echo "$node" >> /var/lib/ansible/inventory
  echo "$node openshift_hostname=$node openshift_public_hostname=$node openshift_node_labels=\"{'region': 'primary', 'zone': 'default'}\"" >> /var/lib/ansible/inventory
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

# NOTE: docker-storage-setup hangs during cloud-init because systemd file is set
# to run after cloud-final.  Temporarily move out of the way (as we've already done storage setup
if [ -e /usr/lib/systemd/system/docker-storage-setup.service ]; then
    mv /usr/lib/systemd/system/docker-storage-setup.service $HOME
    systemctl daemon-reload
fi

# NOTE: Ignore the known_hosts check/propmt for now:
export ANSIBLE_HOST_KEY_CHECKING=False
ansible-playbook --inventory /var/lib/ansible/inventory $HOME/openshift-ansible/playbooks/byo/config.yml > /var/log/ansible.$$ 2>&1

# Move docker-storage-setup unit file back in place
mv $HOME/docker-storage-setup.service /usr/lib/systemd/system
systemctl daemon-reload

mv /var/lib/ansible/inventory.started /var/lib/ansible/inventory.deployed
