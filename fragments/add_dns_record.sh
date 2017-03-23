#!/bin/bash
# Update the DNS server with a record for this host

set -eu
set -x
set -o pipefail

DNS_UPDATE_KEY="%DNS_UPDATE_KEY%"

if [ -z "$DNS_UPDATE_KEY" ]; then
    echo "Skipping the DNS update because the key is empty."
    exit
fi

if yum info python-dns; then
    retry yum -y install python-dns
else
    retry yum -y install python2-dns
fi

HOSTNAME="$(hostname --fqdn)"

for DNS_SERVER in "%DNS_SERVERS%"; do
    # NOTE: the dot after the hostname is necessary
    /usr/local/bin/update_dns  -s "$DNS_SERVER" -k "$DNS_UPDATE_KEY" "$HOSTNAME." "%IP_ADDRESS%"
done
