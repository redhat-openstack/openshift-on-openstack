#!/bin/bash

set -eu
set -x
set -o pipefail

ifup eth1

iptables -A OUTPUT -o eth0 -s $CONTAINER_NETWORK_CIDR -m state --state NEW -j DROP
