#!/bin/bash
#
# Register with subscription manager and enable required RPM respositories
#
# ENVVARS:
#   RHN_USERNAME - a valid RHN username with access to OpenShift entitlements
#   RHN_PASSWORD - password for the RHN user
#   POOL_ID - OPTIONAL - a specific pool with OpenShift entitlements
#   EXTRA_POOL_IDS - OPTIONAL - additional pools

# Exit on command fail
set -eu
set -x

# Return the final non-zero exit code of a failed pipe (or 0 for success)
set -o pipefail

# =============================================================================
# MAIN
# =============================================================================

# Do nothin if either username or password is missing
[ -n "$RHN_USERNAME" -a -n "$RHN_PASSWORD" ] || exit 0

# Register this host with RHN
retry subscription-manager register \
      --username="$RHN_USERNAME" \
      --password="$RHN_PASSWORD"

# Attach to an entitlement pool
if [ -n "$POOL_ID" ]; then
    subscription-manager attach --pool $POOL_ID
else
    subscription-manager attach --auto
fi

if [ -n "$EXTRA_POOL_IDS" ]; then
    subscription-manager attach --pool $EXTRA_POOL_IDS
fi

# Select the YUM repositories to use
subscription-manager repos --disable="*"
subscription-manager repos \
                     --enable="rhel-7-server-rpms" \
                     --enable="rhel-7-server-extras-rpms" \
                     --enable="rhel-7-server-optional-rpms" \
                     --enable="rhel-7-server-ose-3.1-rpms"

# Allow RPM integrity checking
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
