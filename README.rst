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


Prerequisities
==============

1. OpenStack version Juno or later with the Heat, Neutron, Ceilometer services
running

2. CentOS_ 7.1 cloud image (we leverage cloud-init) loaded in Glance for OpenShift Origin Deployments.  RHEL_ 7.1 cloud image if doing Atomic Enterprise or OpenShift Enterprise

3. An SSH keypair loaded to Nova

4. A (Neutron) network with a pool of floating IP addresses available

CentOS and RHEL are the only tested distros for now.

.. _CentOS: http://www.centos.org/
.. _RHEL: https://access.redhat.com/downloads

Deployment
==========

You can pass all environment variables to heat on command line.  However, two example environment files have been given.

* ``env_origin.yaml`` is an example of the variables to deploy an OpenShift Origin 3 environment.
* ``env_aop.yaml`` is an example of the variables to deploy an Atomic Enterprise or OpenShift Enterprise 3 environment.  Note deployment type should be *openshift-enterprise* for OpenShift or *atomic-enterprise* for Atomic Enterprise.  Also, a valid RHN subscription is required for deployment.

Assuming your external network is called ``ext_net``, your SSH key is ``default`` and your CentOS 7.1 image is ``centos71`` and your domain name is ``example.com``, this is how you deploy OpenShift Origin:

::

  cat << EOF > env.yaml
  parameters:
    ssh_key_name: default
    server_image: centos71
    flavor: m1.medium
    external_network: ext_net
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

  EOF

   git clone https://github.com/redhat-openstack/openshift-on-openstack.git
   heat stack-create my_openshift -e env.yaml -e openshift-on-openstack/env_single.yaml -f openshift-on-openstack/openshift.yaml

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

Post-Deployment Setup
=====================

The OpenShift deployed by these templates doesn't create the default router,
resource registry or users automatically. Right now, you should do this
manually.

You can get the IP address of the OpenShift master node with ``heat output-show
my_openshift master_ip``.

::

   ssh cloud-user@MASTER_NODE_IP
   sudo -i

   # Change the master node to allow scheduling pods to it
   # By default the master has SchedulingDisabled
   oc edit node openshift-master.example.com
   ### Remove the line: unschedulable: true

   # Create the router
   CA=/etc/openshift/master

   ### NOTE: If origin, this should be CA=/etc/origin/master
   oadm ca create-server-cert --signer-cert=$CA/ca.crt --signer-key=$CA/ca.key \
      --signer-serial=$CA/ca.serial.txt --hostnames='*.cloudapps.example.com' --cert=cloudapps.crt --key=cloudapps.key
   cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem

   ### NOTE: If origin, credentials should be /etc/origin/master/openshift-router.kubeconfig
   oadm router --replicas=1 --default-cert=cloudapps.router.pem \
     --credentials=/etc/openshift/master/openshift-router.kubeconfig \
     --selector='region=infra' --service-account=router

     # Note - you will want to capture your stats user password
   iptables -I OS_FIREWALL_ALLOW -p tcp -m tcp --dport 1936 -j ACCEPT
   service iptables save; service iptables restart

   # Validate the router is running
   oc get pods
   oc describe pod <router name>

   # Create the resource registry
   ### NOTE: On Origin this will be /etc/origin/master/openshift-registry.kubeconfig
   oadm registry --create --config=/etc/openshift/master/admin.kubeconfig \
      --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
      --selector="region=infra"

   # Validate the registry is running
   oc get pods

Accessing the Web UI
====================

You can get the URL for the OpenShift Console (the web UI) from Heat by running
``heat output-show my_openshift master_console_url``.

Currently, the UI and the resolution for the public hostnames that will be associated
to services running in OpenShift is dependent on the DNS created internally by
the these Heat templates.

So to access the UI, you can get the DNS IP address by ``heat output-show
my_openshift dns_ip`` and put ``nameserver $DNS_IP`` as the first entry in your
``/etc/resolv.conf``.

We plan to let you supply your own DNS that has the OpenShift cloud domain and
all the nodes pre-configured and also to optionally have the UI server bind to
its IP address instead of the hostname.


Current Status
==============

1. The CA certificate used with OpenShift is currently not configurable and
   not available from the outside.

2. The apps cloud domain is hardcoded for now. We need to make this configurable.


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
