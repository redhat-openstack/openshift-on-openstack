#!/bin/bash

set -eux
set -o pipefail

[ -z "$REPOLIST" ] && exit 0
cd /etc/yum.repos.d
for repo in $REPOLIST;do
    fname=`echo "$repo"|md5sum |awk '{ print $1}'`.repo
    curl -o $fname $repo
done
