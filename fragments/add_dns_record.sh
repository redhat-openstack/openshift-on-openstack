#!/bin/bash
# Update the DNS server with a record for this host

set -eu
set -x
set -o pipefail

DNS_UPDATE_KEY="%DNS_UPDATE_KEY%"
DNS_UPDATE_KEYNAME="%DNS_UPDATE_KEYNAME%"

if [ -z "$DNS_UPDATE_KEY" ]; then
    echo "Skipping the DNS update because the key is empty."
    exit
fi

if [ -z "$DNS_UPDATE_KEYNAME" ]; then
    export DNS_UPDATE_KEYNAME='update-key'
fi

if yum info python-dns; then
    retry yum -y install python-dns
else
    retry yum -y install python2-dns
fi


NAME="%DNS_ENTRY%"

# If we didn't get an explicit name, use this server's hostname
if [ -n "$NAME" -a "${NAME:0:1}" = "%" -a "${NAME: -1}" = "%" ]; then
    NAME="$(hostname)"
fi

# NOTE: the dot after the hostname is necessary
/usr/local/bin/update_dns -z "%ZONE%" -s "%DNS_UPDATE_MASTER%" -n "$DNS_UPDATE_KEYNAME" -k "$DNS_UPDATE_KEY" "$NAME." "%IP_ADDRESS%"
