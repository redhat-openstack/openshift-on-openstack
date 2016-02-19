#!/bin/bash

set -eux
set -o pipefail

function notify_success() {
    $WC_NOTIFY --data-binary  "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

function notify_failure() {
    $WC_NOTIFY --data-binary "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}
if [ -e /run/ostree-booted ]; then
    atomic host upgrade || notify_failure "failed to run 'atomic host upgrade'"
else
    yum install -y deltarpm || notify_failure "could not install deltarpm"
    yum -y update || notify_failure "could not update RPMs"
fi
