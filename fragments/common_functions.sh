# Send success status to OpenStack WaitCondition
function notify_success() {
    $WC_NOTIFY --data-binary \
               "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

# Send success status to OpenStack WaitCondition
function notify_failure() {
    $WC_NOTIFY --data-binary \
               "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}

function sudo_enable_from_ssh() {
    # Required for SSH pipelining
    sed -i "/requiretty/s/^/#/" /etc/sudoers
}

# add the local nameserver to the beginning of the local resolver list
function add_nameserver() {
    # NAMESERVER_IP=$1
    sed -i "/search openstacklocal.*/anameserver $1" /etc/resolv.conf
}

# All hosts must have an external disk device (cinder?) for docker storage
function docker_set_storage_device() {
    # By default the cinder volume is mapped to virtio-first_20_chars of cinder
    # volume ID under /dev/disk/by-id/
    devlink=/dev/disk/by-id/virtio-${1:0:20}
    if ! [ -e "$devlink" ];then
        # It might be that disk is not present under /dev/disk/by-id/
        # https://ask.openstack.org/en/question/50882/are-devdiskby-id-symlinks-unreliable/
        # then just find first disk which has no partition
        for dev in /dev/vdb /dev/vda; do
            if [ -b $dev -a ! -b ${dev}1 ]; then
                docker_dev=$dev
                break
            fi
        done
    else
        # docker-storage-setup can not deal with /dev/disk/by-id/ symlinks
        docker_dev=$(readlink -f $devlink)
    fi

    if ! [ -b "$docker_dev" ]; then
        notify_failure "docker volume device $docker_dev does not exist"
    fi

    cat << EOF > /etc/sysconfig/docker-storage-setup
DEVS=$docker_dev
VG=docker-vg
EOF
}

function docker_set_storage_quota() {
    echo "EXTRA_DOCKER_STORAGE_OPTIONS=\"--storage-opt dm.basesize=$1G\"" \
        >> /etc/sysconfig/docker-storage-setup
    echo "DOCKER_STORAGE_OPTIONS=\"--storage-opt dm.basesize=$1G\"" \
        > /etc/sysconfig/docker-storage
}
