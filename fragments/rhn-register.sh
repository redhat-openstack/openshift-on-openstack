#!/bin/bash
#
# Register with subscription manager and enable required RPM respositories
#
# ENVVARS:
#   RHN_USERNAME - a valid RHN username with access to OpenShift entitlements
#   RHN_PASSWORD - password for the RHN user
#   POOL_ID - OPTIONAL - a specific pool with OpenShift entitlements
#   EXTRA_POOL_IDS - OPTIONAL - additional pools
#   SAT6_HOSTNAME - The hostname of the Sat6 server to register to
#   SAT6_ORGANIZAION - An Organization string to aid grouping of hosts
#   SAT6_ACTIVATIONKEY - A string used to authorize the registration
#
#   OCP_VERSION - the version of the OS repo to enable
OCP_VERSION=${OCP_VERSION:-"3.2"}

# Exit on command fail
set -eu
set -x

# Return the final non-zero exit code of a failed pipe (or 0 for success)
set -o pipefail

function use_satellite6() {
    [ -n "$SAT6_HOSTNAME" ]
}

function use_rhn() {
    [ -n "$RHN_USERNAME" -a -n "$RHN_PASSWORD" ]
}

function register_rhn() {
    # RHN_USERNAME=$1
    # RHN_PASSWORD=$2
    # RHN_CONFIG_OPTIONS=$3

    if [ -n "$3" ]; then
        subscription-manager config  $3
    fi

    retry subscription-manager register --username="$1" --password="$2"
}

function install_sat6_ca_certs() {
    # SAT6_HOSTNAME=$1
    local SAT6_KEY_RPM="katello-ca-consumer-$1"
    local SAT6_KEY_RPM_URL="http://${1}/pub/katello-ca-consumer-latest.noarch.rpm"

    if ! rpm -q --quiet $SAT6_KEY_RPM ; then
        retry yum -y localinstall $SAT6_KEY_RPM_URL
    fi
}

function register_sat6() {
    # SAT6_ORGANIZATION=$1
    # SAT6_ACTIVATIONKEY=$2
    # register as a sat6 client
    retry subscription-manager register --org="$1" --activationkey="$2"
}

# =============================================================================
# MAIN
# =============================================================================

if use_satellite6 ; then
    install_sat6_ca_certs $SAT6_HOSTNAME
    register_sat6 $SAT6_ORGANIZATION $SAT6_ACTIVATIONKEY
elif use_rhn ; then
    register_rhn $RHN_USERNAME $RHN_PASSWORD "$RHN_CONFIG_OPTIONS"
else
    exit 0
fi

# Attach to an entitlement pool
if [ -n "$POOL_ID" ]; then
    retry subscription-manager attach --pool $POOL_ID
else
    retry subscription-manager attach --auto
fi

if [ -n "$EXTRA_POOL_IDS" ]; then
    retry subscription-manager attach --pool $EXTRA_POOL_IDS
fi

# Select the YUM repositories to use
retry subscription-manager repos --disable="*"
retry subscription-manager repos \
                     --enable="rhel-7-server-rpms" \
                     --enable="rhel-7-server-extras-rpms" \
                     --enable="rhel-7-server-optional-rpms" \
                     --enable="rhel-7-server-ose-$OCP_VERSION-rpms"

# version 3.5+ require fast-datapath
if [ $(expr "$OCP_VERSION" \> 3.4) -eq 1 ] ; then
    retry subscription-manager repos --enable rhel-7-fast-datapath-rpms
fi

# Allow RPM integrity checking
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
