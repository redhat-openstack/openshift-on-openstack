#!/bin/bash
#
# Download and add a set of additional YUM repo files
#   Apply a sum to each filename so that repo files from different sources but
#   with the same name (ie "testing.repo") will not overwrite each other.
#
# ENVVARS
#
#  REPOLIST - a whitespace delimited list of URLs for YUM repo files.
#

set -eux
set -o pipefail

# The target location for downloaded repo files.  Default to system location
REPODIR=${REPODIR:-"/etc/yum.repos.d"}

# Bypass this function when no additional repos are provided.
[ -z "$REPOLIST" ] && exit 0

# Pull down each repo file from the URL, renaming it to avoid filename overload
for repofile_url in $REPOLIST; do
    # Create a path from the URL file and a hash to avoid conflict
    url_filename=$(basename $repofile_url)
    url_checksum=$(echo "$repofile_url" | md5sum | cut -f1 -d' ')
    curl -o ${REPODIR}/${url_filename}-${url_checksum}.repo $repofile_url
done
