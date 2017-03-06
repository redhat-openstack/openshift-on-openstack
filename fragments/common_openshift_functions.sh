function disable_peerdns() {
    # INTERFACE=$1
    echo sed -i '/^PEERDNS=/s/=.*/="no"/' /etc/sysconfig/network-scripts/ifcfg-$1
}

# workaround for openshift-ansible - symlinks are created in /usr/local/bin but
# this path is not by default in sudo secure_path so ansible fails
function sudo_set_secure_path() {
    # SECURE_PATH=$1
    sed -i "/secure_path = /s|=.*|= $1|" /etc/sudoers
}

#
# - docker ---------------------------------------------------------
#

function docker_install_and_enable() {
    if ! rpm -q docker
    then
        retry yum -y install docker || notify_failure "could not install docker"
    fi
    systemctl enable docker
}


function docker_version() {
    # MAJ_MIN=$1 - 'major' or 'minor'
    local version=$(rpm -q docker --qf '%{VERSION}')
    [ $1 = "major" ] && echo $version | cut -d. -f1 && return
    [ $1 = "minor" ] && echo $version | cut -d. -f2 && return
    echo $version
}

function docker_set_trusted_registry() {
    # TRUSTED_REGISTRY=$1
    echo "INSECURE_REGISTRY='--insecure-registry $1'" >> /etc/sysconfig/docker
}

#
# - systemd ---------------------------------------------------------
#

function systemd_add_docker_socket() {
    # Workaround for https://bugzilla.redhat.com/show_bug.cgi?id=1289851
    # can be removed once docker 1.10 is released

    # make a "local" copy of the docker service unit file
    cp /lib/systemd/system/docker.service /etc/systemd/system/docker.service
    # Add a new unit file requirement
    sed -i '/Wants=docker-storage-setup.service/aRequires=docker.socket' \
        /etc/systemd/system/docker.service

    # create the docker socket unit file
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

    # Force re-read of systemd configuration and apply
    systemctl daemon-reload
}
