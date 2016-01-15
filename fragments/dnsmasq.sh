#!/bin/bash

set -eu
set -o pipefail

function notify_success() {
    $WC_NOTIFY --data-binary  "{\"status\": \"SUCCESS\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 0
}

function notify_failure() {
    $WC_NOTIFY --data-binary "{\"status\": \"FAILURE\", \"reason\": \"$1\", \"data\": \"$1\"}"
    exit 1
}

systemctl is-enabled os-collect-config || notify_failure "os-collect-config service is not installed or enabled"

retry yum install -y dnsmasq || notify_failure "can't install dnsmasq"
\cp /root/dnsmasq.conf /etc/dnsmasq.conf
systemctl enable dnsmasq || notify_failure "can't enable dnsmasq"
systemctl restart dnsmasq || notify_failure "can't start dnsmasq"

notify_success "DNS node is ready."
