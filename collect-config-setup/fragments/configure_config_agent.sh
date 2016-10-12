#!/bin/bash
set -eux

# this file should be included in write_files section for the node
source /usr/local/share/openshift-on-openstack/common_functions.sh

# on Atomic host os-collect-config runs inside a container which is
# fetched&started in another step
[ -e /run/ostree-booted ] && exit 0

# os-apply-config templates directory
oac_templates=/usr/libexec/os-apply-config/templates
mkdir -p $oac_templates/etc

# initial /etc/os-collect-config.conf
cat <<EOF >/etc/os-collect-config.conf
[DEFAULT]
command = os-refresh-config
EOF

# template for building os-collect-config.conf for polling heat
cat <<EOF >$oac_templates/etc/os-collect-config.conf
[DEFAULT]
{{^os-collect-config.command}}
command = os-refresh-config
{{/os-collect-config.command}}
{{#os-collect-config}}
{{#command}}
command = {{command}}
{{/command}}
{{#polling_interval}}
polling_interval = {{polling_interval}}
{{/polling_interval}}
{{#cachedir}}
cachedir = {{cachedir}}
{{/cachedir}}
{{#collectors}}
collectors = {{.}}
{{/collectors}}

{{#cfn}}
[cfn]
{{#metadata_url}}
metadata_url = {{metadata_url}}
{{/metadata_url}}
stack_name = {{stack_name}}
secret_access_key = {{secret_access_key}}
access_key_id = {{access_key_id}}
path = {{path}}
{{/cfn}}

{{#heat}}
[heat]
auth_url = {{auth_url}}
user_id = {{user_id}}
password = {{password}}
project_id = {{project_id}}
stack_id = {{stack_id}}
resource_name = {{resource_name}}
{{/heat}}

{{#request}}
[request]
{{#metadata_url}}
metadata_url = {{metadata_url}}
{{/metadata_url}}
{{/request}}

{{/os-collect-config}}
EOF
mkdir -p $oac_templates/var/run/heat-config

# template for writing heat deployments data to a file
echo "{{deployments}}" > $oac_templates/var/run/heat-config/heat-config

# os-refresh-config scripts directory
# This moves to /usr/libexec/os-refresh-config in later releases
orc_scripts=/opt/stack/os-config-refresh
for d in pre-configure.d configure.d migration.d post-configure.d; do
    install -m 0755 -o root -g root -d $orc_scripts/$d
done

# os-refresh-config script for running os-apply-config
cat <<EOF >$orc_scripts/configure.d/20-os-apply-config
#!/bin/bash
set -ue

exec os-apply-config
EOF
chmod 700 $orc_scripts/configure.d/20-os-apply-config

ln -s /usr/share/openstack-heat-templates/software-config/elements/heat-config/os-refresh-config/configure.d/55-heat-config $orc_scripts/configure.d/55-heat-config

# config hook for shell scripts
hooks_dir=/var/lib/heat-config/hooks
mkdir -p $hooks_dir

# install hook for configuring with shell scripts
ln -s /usr/share/openstack-heat-templates/software-config/heat-container-agent/scripts/hooks/script $hooks_dir/script

# install heat-config-notify command
ln -s /usr/share/openstack-heat-templates/software-config/elements/heat-config/bin/heat-config-notify /usr/bin/heat-config-notify

# run once to write out /etc/os-collect-config.conf
# use notify_failure from common_functions.sh to
# make sure cloud-init reports failure
os-collect-config --one-time --debug ||
    notify_failure "failed to run os-collect-config"

# check that a valid metadata_url was set
curl "$(grep metadata_url /etc/os-collect-config.conf |sed 's/metadata_url = //')" ||
    notify_failure "failed to connect to os-collect-config metadata_url"

cat /etc/os-collect-config.conf
