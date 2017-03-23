#!/bin/bash
#
# Register with subscription manager and enable required RPM respositories
#
# ENVVARS:
#   CA_CERT - a ca certificate to be added to trust chain

# Exit on command fail
set -eu
set -x

# Return the final non-zero exit code of a failed pipe (or 0 for success)
set -o pipefail

# =============================================================================
# MAIN
# =============================================================================

if [ -n "$CA_CERT" ] ; then
    update-ca-trust enable
    cat >/etc/pki/ca-trust/source/anchors/ca.crt <<EOF
$CA_CERT
EOF
    update-ca-trust extract
else
    exit 0
fi
