#!/bin/bash

set -eu
set -o pipefail

retry yum install -y dnsmasq
\cp /root/dnsmasq.conf /etc/dnsmasq.conf
systemctl enable dnsmasq
systemctl restart dnsmasq
