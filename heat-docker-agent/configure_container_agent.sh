#!/bin/bash

set -eux

# openshift-ansible
yum update -y && yum clean all
yum -y install centos-release-openstack-liberty
yum install -y net-tools bind-utils git python-pip \
  sysvinit-tools openstack-heat-templates \
  os-collect-config os-apply-config \
  os-refresh-config dib-utils python-pip \
  python-docker-py python-yaml python-zaqarclient

#RUN yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-6.noarch.rpm
yum install -y --enablerepo epel ansible1.9

#git clone --single-branch --branch master https://github.com/openshift/openshift-ansible.git  /usr/share/ansible/openshift-ansible/
git clone --single-branch --branch master https://github.com/jprovaznik/openshift-ansible.git  /usr/share/ansible/openshift-ansible/

#RUN yum -y install docker
yum -y install http://mirror.centos.org/centos/7/extras/x86_64/Packages/docker-1.8.2-10.el7.centos.x86_64.rpm
yum -y install pyOpenSSL

pip install dpath functools32

# os-collect-config
orc_scripts=/usr/libexec/os-refresh-config
heat_templates=/usr/share/openstack-heat-templates
oac_templates=/usr/libexec/os-apply-config/templates
mkdir -p /var/lib/heat-config/hooks
ln -s $heat_templates/software-config/elements/heat-config/bin/heat-config-notify /usr/bin/
ln -s $heat_templates/software-config/heat-container-agent/scripts/hooks/script /var/lib/heat-config/hooks/
mkdir -p $orc_scripts/configure.d
ln -s $heat_templates/software-config/elements/heat-config/os-refresh-config/configure.d/55-heat-config $orc_scripts/configure.d/

mkdir -p $oac_templates/var/run/heat-config
echo "{{deployments}}" > $oac_templates/var/run/heat-config/heat-config

# template for building os-collect-config.conf for polling heat
mkdir -p $oac_templates/etc/
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
collectors = {{collectors}}
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

# os-refresh-config script for running os-apply-config
cat <<EOF >$orc_scripts/configure.d/20-os-apply-config
#!/bin/bash
set -ue

exec os-apply-config
EOF
chmod 700 $orc_scripts/configure.d/20-os-apply-config
