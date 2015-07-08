======================
OpenShift on OpenStack
======================

About
=====

A collection of documentation, Heat templates, Dockerfiles and everything else
that's necessary to deploy OpenShift Origin (v3) on an OpenStack-backed
infrastructure using Atomic Host images.


Prerequisities
==============

1. OpenStack version Juno or later with the Heat, Neutron, Ceilometer services
running

2. CentOS 7.1 cloud image (we leverage cloud-init) loaded in Glance

3. An SSH keypair loaded to Nova

4. A (Neutron) network with a pool of floating IP addresses available

CentOS is the only tested distro for now.


Deployment
==========

Assuming your external network is called ``ext_net``, your SSH key is
``default`` and your CentOS 7.1 image is ``centos71``, this is how you
deploy OpenShift:

::

   git clone https://github.com/redhat-openstack/openshift-on-openstack.git
   heat stack-create my_openshift -f openshift-on-openstack/openshift.yaml \
       -P server_image=centos71 -P external_network=ext_net \
       -P ssh_key_name=default -P node_count=2

The ``node_count`` parameter specifies how many non-master OpenShift nodes you
want to deploy. In the example above, we will deploy one master and two nodes.

The templates are not robust enough to report to Heat when everything
finishes yet. That means that ``heat stack-show my_openshift`` will report a
success too early.

To check that everything is indeed ready, look for ``OpenShift has been
installed.`` in the console log for the OpenShift master node:

::

   openstack console log show openshift-master.example.com| grep "OpenShift.*installed."


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

   # Create default router
   CA=/etc/openshift/master
   oadm create-server-cert --signer-cert=$CA/ca.crt --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt --hostnames='*.cloudapps.example.com' --cert=cloudapps.crt --key=cloudapps.key
   cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem
   oadm router --default-cert=cloudapps.router.pem --credentials=/etc/openshift/master/openshift-router.kubeconfig --selector='region=infra'
   iptables -I OS_FIREWALL_ALLOW -p tcp -m tcp --dport 1936 -j ACCEPT

   # Create the resource registry
   oadm registry --create --credentials=/etc/openshift/master/openshift-registry.kubeconfig --selector="region=infra"


Accessing the Web UI
====================

You can get the URL for the OpenShift Console (the web UI) from Heat by running
``heat output-show my_openshift console_url``.

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

2. The hostnames for all the OpenShift nodes as well as the apps cloud domain
   are hardcoded for now. We need to make these configurable.


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
