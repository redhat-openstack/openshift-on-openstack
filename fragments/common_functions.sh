# Send success status to OpenStack WaitCondition
#  or UpdateWaitConditionHandle
function notify_success() {
    if [[ "$WC_NOTIFY" =~ ^curl ]]; then
        $WC_NOTIFY -k --data-binary \
                "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    else
        /usr/bin/cfn-signal -e 0 -r "$1" -s "SUCCESS" --id "00000" -d "$1" "$WC_NOTIFY"
    fi
    exit 0
}

# Send failure status to OpenStack WaitCondition
#  or UpdateWaitConditionHandle
function notify_failure() {
    if [[ "$WC_NOTIFY" =~ ^curl ]]; then

        $WC_NOTIFY -k  --data-binary \
               "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    else
        /usr/bin/cfn-signal -r "$1" -s "FAILURE" -r "$1"  --id "00000" -d "$1" "$WC_NOTIFY"
    fi
    exit 1
}

function sudo_enable_from_ssh() {
    # Required for SSH pipelining
    sed -i "/requiretty/s/^/#/" /etc/sudoers
}

# All hosts must have an external disk device (cinder?) for docker storage
function docker_set_storage_device() {
    # By default the cinder volume is mapped to virtio-first_20_chars of cinder
    # volume ID under /dev/disk/by-id/
    devlink=/dev/disk/by-id/virtio-${1:0:20}
    docker_dev=""
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
