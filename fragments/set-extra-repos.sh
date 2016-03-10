#!/bin/bash

set -eux
set -o pipefail

[ -z "$REPOLIST" ] && exit 0
cd /etc/yum.repos.d
for repo in $REPOLIST;do
    curl -O $repo
done
