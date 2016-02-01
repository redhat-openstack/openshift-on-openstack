======================
OpenShift on OpenStack
======================

About
=====

A collection of documentation, Heat_ templates, configuration and everything
else that's necessary to deploy OpenShift_ on OpenStack_.

.. _Heat: https://wiki.openstack.org/wiki/Heat
.. _OpenShift: http://www.openshift.org/
.. _OpenStack: http://www.openstack.org/


Prerequisites
=============

1. OpenStack version Juno or later with the Heat, Neutron, Ceilometer services
running

2. CentOS_ 7.2 cloud image (we leverage cloud-init) loaded in Glance for OpenShift Origin Deployments.  RHEL_ 7.2 cloud image if doing Atomic Enterprise or OpenShift Enterprise

3. An SSH keypair loaded to Nova

4. A (Neutron) network with a pool of floating IP addresses available

CentOS and RHEL are the only tested distros for now.

.. _CentOS: http://www.centos.org/
.. _RHEL: https://access.redhat.com/downloads

Following steps can be used to setup all-in-one testing/developer environment:

::

  cd $HOME
  systemctl stop NetworkManager
  systemctl disable NetworkManager
  yum -y install openstack-packstack libvirt git
  mv /var/lib/libvirt/images /home
  ln -s /home/images /var/lib/libvirt/images
  packstack --allinone --os-heat-install=y --keystone-admin-passwd=password --keystone-demo-passwd=password --provision-all-in-one-ovs-bridge=y --os-heat-cfn-install=y
  git clone https://github.com/redhat-openstack/openshift-on-openstack.git
  curl -O http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
  source keystonerc_admin
  glance image-create --name centos72 --disk-format qcow2 --container-format bare --is-public True --file CentOS-7-x86_64-GenericCloud.qcow2
  nova keypair-add --pub-key ~/.ssh/id_rsa.pub default

Deployment
==========

You can pass all environment variables to heat on command line.  However, two example environment files have been given.

* ``env_origin.yaml`` is an example of the variables to deploy an OpenShift Origin 3 environment.
* ``env_aop.yaml`` is an example of the variables to deploy an Atomic Enterprise or OpenShift Enterprise 3 environment.  Note deployment type should be *openshift-enterprise* for OpenShift or *atomic-enterprise* for Atomic Enterprise.  Also, a valid RHN subscription is required for deployment.

Assuming your external network is called ``public``, your SSH key is ``default`` and your CentOS 7.2 image is ``centos72`` and your domain name is ``example.com``, this is how you deploy OpenShift Origin:

::

  cat << EOF > env.yaml
  parameters:
    ssh_key_name: default
    server_image: centos72
    lb_image: centos72
    flavor: m1.medium
    external_network: public
    dns_nameserver: 8.8.4.4,8.8.8.8
    node_count: 2
    rhn_username: ""
    rhn_password: ""
    rhn_pool: ''
    deployment_type: origin
    domain_name: "example.com"
    dns_hostname: "ns"
    master_hostname_prefix: "origin-master"
    node_hostname_prefix: "origin-node"
    ssh_user: cloud-user
    master_docker_volume_size_gb: 25
    node_docker_volume_size_gb: 25
    deploy_router: False
    deploy_registry: False
  EOF

   git clone https://github.com/redhat-openstack/openshift-on-openstack.git
   heat stack-create my_openshift -t 180 -e env.yaml -e openshift-on-openstack/env_single.yaml -f openshift-on-openstack/openshift.yaml

The ``node_count`` parameter specifies how many non-master OpenShift nodes you
want to deploy. In the example above, we will deploy one master and two nodes.

The templates will report stack completion back to Heat only when the whole 
OpenShift setup is finished.

To confirm that everything is indeed ready, look for ``OpenShift has been
installed.`` in the OpenShift master node data in the stack output:

::

   heat output-show my_openshift master_data

Multiple Master Nodes
=====================

You can deploy OpenShift with multiple master nodes using the 'native' HA
method (see https://docs.openshift.org/latest/install_config/install/advanced_install.html#multiple-masters
for details):

::

   heat stack-create my_openshift -e env.yaml -e openshift-on-openstack/env_ha.yaml -f openshift-on-openstack/openshift.yaml

Three master nodes and a loadbalancer will be deployed. Console and API URLs
then point to the loadbalancer server which distributes requests across all
three nodes. You can get the URLs from Heat by running
``heat output-show my_openshift lb_console_url`` and
``heat output-show my_openshift lb_api_url``.

LDAP authentication
===================

You can use an external LDAP server to authenticate OpenShift users. Update
parameters in ``env_ldap.yaml`` file and include this environment file on stack
create:

::

    heat stack-create my_openshift -e env.yaml -e openshift-on-openstack/env_ha.yaml -e openshift-on-openstack/env_ldap.yaml -f openshift-on-openstack/openshift.yaml

Example of using an Active Directory server:

::

   parameter_defaults:
       ldap_hostname: <ldap hostname>
       ldap_ip: <ip of ldap server>
       ldap_url: ldap://<ldap hostname>:389/CN=Users,DC=example,DC=openshift,DC=com?sAMAccountName
       ldap_bind_dn: CN=Administrator,CN=Users,DC=example,DC=openshift,DC=com?sAMAccountName
       ldap_bind_password: <admin password>

Accessing the Web UI
====================

You can get the URL for the OpenShift Console (the web UI) from Heat by running
``heat output-show my_openshift master_console_url``.

Currently, the UI and the resolution for the public hostnames that will be associated
to services running in OpenShift is dependent on the DNS created internally by
these Heat templates.

So to access the UI, you can get the DNS IP address by ``heat output-show
my_openshift dns_ip`` and put ``nameserver $DNS_IP`` as the first entry in your
``/etc/resolv.conf``.

We plan to let you supply your own DNS that has the OpenShift cloud domain and
all the nodes pre-configured and also to optionally have the UI server bind to
its IP address instead of the hostname.

Retrieving the CA certificate
=============================

You can retrieve the CA certificate that was generated during the Openshift
installation by running

::

  heat output-show --format=raw my_openshift ca_cert > ca.crt
  heat output-show --format=raw my_openshift ca_key > ca.key

Current Status
==============

1. The CA certificate used with OpenShift is currently not configurable.

2. The apps cloud domain is hardcoded for now. We need to make this configurable.

Prebuild images
===============

A `customize-disk-image` script is provided to preinstall Openshift packages.

``./customize-disk-image --disk rhel7.2.qcow2 --sm-credentials user:password``

The modified image must be uploaded into Glance and used as the server image
for the heat stack with the `server_image` and `lb_image` parameters.

Copyright
=========

Copyright 2015 Red Hat, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
