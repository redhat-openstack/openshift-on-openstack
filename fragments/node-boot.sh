#!/bin/bash

set -eu
set -x
set -o pipefail

function notify_success() {
    $WC_NOTIFY --data-binary  "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

function notify_failure() {
    $WC_NOTIFY --data-binary "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}

# Required for SSH pipelining
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# master and nodes
# Set the DNS to the one provided
sed -i 's/search openstacklocal.*/&\nnameserver $DNS_IP/' /etc/resolv.conf
sed -i -e 's/^PEERDNS.*/PEERDNS="no"/' /etc/sysconfig/network-scripts/ifcfg-eth0

# workaround for openshift-ansible - symlinks are created in /usr/local/bin but
# this path is not by default in sudo secure_path so ansible fails
sed -i 's,secure_path = /sbin:/bin:/usr/sbin:/usr/bin,secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin,' /etc/sudoers

# Required for SSH pipelining
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

[ -e /run/ostree-booted ] && notify_success "OpenShift node has been prepared for running ansible."

# Install Docker and prep storage
retry yum -y install docker
echo "INSECURE_REGISTRY='--insecure-registry 0.0.0.0/0'" >> /etc/sysconfig/docker
systemctl enable docker

# Setup Docker Storage Volume Group
if ! [ -b /dev/vdb ]; then
  echo "ERROR: device /dev/vdb does not exist" >&2
  exit 1
fi

systemctl enable lvm2-lvmetad
systemctl start lvm2-lvmetad
cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/vdb
VG=docker-vg
EOF

/usr/bin/docker-storage-setup

notify_success "OpenShift node has been prepared for running ansible."
