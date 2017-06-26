#!/bin/sh
#
# Disable IPv6 system wide and permanently
#
# Live
sysctl -w net.ipv6.conf.eth0.disable_ipv6=1

# Permanently
cat > /etc/sysctl.d/10-disable-ipv6.conf <<EOF
net.ipv6.conf.eth0.disable_ipv6=1
EOF
