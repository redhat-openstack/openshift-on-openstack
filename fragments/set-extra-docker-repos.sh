#!/bin/bash

set -eux
set -o pipefail

CFGFILE=${CFGFILE:-"/etc/sysconfig/docker"}

# Bypass this function when no additional repos are provided.
[ -z "$REPOLIST" ] && exit 0

registry_list=''
insecure_list=''
# Pull down each repo file from the URL, renaming it to avoid filename overload
for repo in $REPOLIST; do
    insecure=false
    if [[ "$repo" == *"#insecure" ]]; then
        insecure=true
        repo=${repo%#insecure}
    fi
    registry_list="$registry_list --add-registry $repo"
    $insecure && insecure_list="$insecure_list --insecure-registry $repo"
done

if [ -n "$registry_list" ]; then
    if grep -q "^ADD_REGISTRY='\(.*\)'" $CFGFILE; then
        sed -i "s/^ADD_REGISTRY='\(.*\)'/ADD_REGISTRY='\1 $registry_list'/" $CFGFILE
    else
        echo "ADD_REGISTRY='$registry_list'" >> $CFGFILE
    fi
fi

if [ -n "$insecure_list" ]; then
    if grep -q "^INSECURE_REGISTRY='\(.*\)'" $CFGFILE; then
        sed -i "s/^INSECURE_REGISTRY='\(.*\)'/INSECURE_REGISTRY='\1 $insecure_list'/" $CFGFILE
    else
        echo "INSECURE_REGISTRY='$insecure_list'" >> $CFGFILE
    fi
fi
