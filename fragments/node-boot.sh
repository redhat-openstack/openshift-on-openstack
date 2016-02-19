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

# Install Docker and prep storage
rpm -q docker || yum -y install docker || notify_failure "could not install docker"
echo "INSECURE_REGISTRY='--insecure-registry 0.0.0.0/0'" >> /etc/sysconfig/docker
systemctl enable docker

# Workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1289851
# can be removed once docker 1.10 is released
cp /lib/systemd/system/docker.service /etc/systemd/system/docker.service
sed -i 's/Wants=docker-storage-setup.service/&\nRequires=docker.socket/' /etc/systemd/system/docker.service
cat << EOF > /etc/systemd/system/docker.socket
[Unit]
Description=Docker Socket for the API
PartOf=docker.service

[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=root

[Install]
WantedBy=sockets.target
EOF
systemctl daemon-reload

# Required for SSH pipelining
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

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
