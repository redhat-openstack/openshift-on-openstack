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

#[ -e /run/ostree-booted ] && notify_success "OpenShift node has been prepared for running ansible."
#systemctl is-enabled os-collect-config || notify_failure "os-collect-config service is not installed or enabled"

# master and nodes
sed -i -e 's/^PEERDNS.*/PEERDNS="no"/' /etc/sysconfig/network-scripts/ifcfg-eth0

if [ -e /run/ostree-booted ]; then
    # Set the DNS to the one provided
    cp /etc/resolv.conf /etc/resolv.conf.local
    # FIXME - the clean way would be to set nameserver for openstack's neutron network
    sed -i 's/search openstacklocal.*/&\nnameserver $DNS_IP/' /etc/resolv.conf

    HOME=/root
    mv /etc/systemd/system/multi-user.target.wants/docker-storage-setup.service $HOME
    systemctl daemon-reload

    # Setup Docker Storage Volume Group
    if ! [ -b /dev/vdb ]; then
      echo "ERROR: device /dev/vdb does not exist" >&2
      notify_failure "device /dev/vdb does not exist"
    fi

    systemctl enable lvm2-lvmetad
    systemctl start lvm2-lvmetad
cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS=/dev/vdb
VG=docker-vg
EOF
    /usr/bin/docker-storage-setup || notify_failure "failed to run docker-storage-setup"
    systemctl start docker --ignore-dependencies || notify_failure "failed to start docker"

    docker pull jprovaznik/ooshift-dns
    docker run -d -p 53:53/udp -v /var/log:/var/log -v /etc/hosts:/etc/hosts -v /etc/dnsmasq.conf:/etc/dnsmasq.conf -v /etc/resolv.conf.local:/etc/resolv.conf --name dnsmasq jprovaznik/ooshift-dns || notify_failure "failed to run dns docker image"
    docker pull jprovaznik/ooshift-heat-agent
    docker run -d --privileged --ipc=host --net=host --pid=host -e HOST=/host -e NAME=rhel-tools -v /run:/run -v /var/log:/var/log -v /etc/localtime:/etc/localtime -v ~/.ssh:/root/.ssh -v /:/host -v /etc/ansible:/etc/ansible -v /var/lib/heat-cfntools:/var/lib/heat-cfntools --name heat-agent jprovaznik/ooshift-heat-agent || notify_failure "failed to run heat-agent docker image"
else
    systemctl is-enabled os-collect-config || notify_failure "os-collect-config service is not installed or enabled"
    yum install -y dnsmasq || notify_failure "can't install dnsmasq"
    systemctl enable dnsmasq || notify_failure "can't enable dnsmasq"
    systemctl restart dnsmasq || notify_failure "can't start dnsmasq"

    yum install -y git httpd-tools || notify_failure "could not install httpd-tools"

    # for centos openssl pkg is not included in pkg requirements yet,
    # make sure it's present
    yum -y install pyOpenSSL || notify_failure "could not install pyOpenSSL"

    # NOTE: install the right Ansible version on RHEL7.1 and Centos 7.1:
    if ! rpm -q epel-release-7-5;then
        yum -y install \
            http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm \
            || notify_failure "could not install EPEL"
    fi
    sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo
    yum -y --enablerepo=epel install ansible || notify_failure "could not install ansible"

    if [ -n "$OPENSHIFT_ANSIBLE_GIT_URL" ] && [ -n "$OPENSHIFT_ANSIBLE_GIT_REV" ]
    then
        git clone "$OPENSHIFT_ANSIBLE_GIT_URL" /usr/share/ansible/openshift-ansible \
            || notify_failure "could not clone openshift-ansible"
        cd /usr/share/ansible/openshift-ansible
        git checkout "$OPENSHIFT_ANSIBLE_GIT_REV"
    else
        yum -y install openshift-ansible-roles openshift-ansible-playbooks \
            || notify_failure "could not install openshift-ansible"
    fi
fi
notify_success "OpenShift node has been prepared for running ansible."

## Tune ansible configuration
#function set_ansible_configuration() {
#    ansible all --connection=local -i "localhost," -m ini_file -a "dest=/etc/ansible/ansible.cfg section='$1' option='$2' value='$3' state=present"
#}
#
#set_ansible_configuration ssh_connection "pipelining" "True"
#set_ansible_configuration ssh_connection "ssh_args" "-o ControlMaster=auto -o ControlPersist=600s"
#set_ansible_configuration ssh_connection "control_path" '%(directory)s/%%h-%%r'
#
#set_ansible_configuration defaults "gathering" "implicit"
#set_ansible_configuration defaults "fact_caching_connection" "/tmp/ansible/facts"
#set_ansible_configuration defaults "fact_caching" "jsonfile"
#set_ansible_configuration defaults "fact_caching_timeout" "600"
#
## Required for SSH pipelining
#sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
