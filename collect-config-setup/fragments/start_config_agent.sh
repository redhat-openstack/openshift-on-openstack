#!/bin/bash
set -eux

# on Atomic host os-collect-config runs inside a container which is
# fetched&started in another step
[ -e /run/ostree-booted ] && exit 0

# enable and start service to poll for deployment changes
systemctl enable os-collect-config
systemctl start --no-block os-collect-config
