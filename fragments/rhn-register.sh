#!/bin/bash

set -eu
set -x
set -o pipefail

if [ -n "$RHN_USERNAME" -a -n "$RHN_PASSWORD" ]; then
    retry subscription-manager register \
                         --username="$RHN_USERNAME" \
                         --password="$RHN_PASSWORD"

    if [ -n "$POOL_ID" ]; then
        retry subscription-manager attach --pool $POOL_ID
    else
        retry subscription-manager attach --auto
    fi

    retry subscription-manager repos --disable="*"
    retry subscription-manager repos \
                         --enable="rhel-7-server-rpms" \
                         --enable="rhel-7-server-extras-rpms" \
                         --enable="rhel-7-server-optional-rpms" \
                         --enable="rhel-7-server-ose-3.0-rpms"
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
fi
