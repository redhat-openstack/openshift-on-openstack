Name: openshift-on-openstack
Version: 0.9.4
Release: 1%{?dist}
Summary: Set of Openstack Heat templates to deploy OpenShift
Group: System Environment/Base
License: ASL 2.0
URL: https://github.com/redhat-openstack/openshift-on-openstack
Source0: https://github.com/redhat-openstack/openshift-on-openstack/archive/v%{version}/openshift-on-openstack-%{version}.tar.gz
BuildArch: noarch

%description
A collection of documentation, Heat templates, configuration and
everything else that's necessary to deploy OpenShift on OpenStack.

%prep
%setup -qn openshift-on-openstack-%{version}

%build

%install
install -d -m 755 %{buildroot}/%{_datadir}/%{name}
install -D -m 755 customize-disk-image %{buildroot}%{_bindir}/customize-disk-image
cp -aR *.yaml %{buildroot}%{_datadir}/%{name}/
cp -aR collect-config-setup/ %{buildroot}%{_datadir}/%{name}
cp -aR fragments/ %{buildroot}%{_datadir}/%{name}
cp -aR templates/ %{buildroot}%{_datadir}/%{name}
cp -aR heat-docker-agent/ %{buildroot}%{_datadir}/%{name}
cp -aR tests/ %{buildroot}%{_datadir}/%{name}

%files
%doc LICENSE.txt README.adoc README_debugging.adoc
%{_datadir}/%{name}
%{_bindir}/customize-disk-image

%changelog
* Wed Oct 19 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.9.4-1
- Use openshift-ansible recommanded way for scaleup
- Add constraints on hostnames
- Documentation improvements
- Fixed master_count evaluation

* Fri Oct 14 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.9.3-1
- Bug fixes:
  - Improve checking of os-collect-config setup
  - Add missing domain to dedicated loadbalancer instance
  - Unify loadbalancer stackname prefix
  - Make sure prepare_registry is a bool value
  - Make use of parameter registry_volume_size
  - Fix scaleup when using volume_quota parameter

* Wed Oct 12 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.9.2-1
- Bug fixes:
  - Set default value for rhn_pool
  - Add default loadbalancer neutron env file
  - Ignore "oadm ipfailover" error state
  - Install missing package python-oslo-log for OSP 9
  - Set load balancer image to rhel when using AOP
  - Fixed schduling on master nodes
  - Return non empty router_ip when using dedicated loadbalancer
- Lots of documentation improvements

* Thu Oct 6 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.9.1-1
- Allow specifying different flavors for every node type
- Bug fixes:
  - Write template files in post cloud-init phase to avoid 64k
    limit of cloud-init
  - Explicitly enable port 53 for DNS server
  - Refactor skip_dns parameter

* Mon Oct 3 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.9.0-1
- Rename 'infra' node to 'bastion'
- Dedicated infra nodes
- Setup masquerading when using flannel
- Allow passing parameters to openshift-ansible as JSON
- Satellite fixes

* Wed Sep 14 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.8.1-1
- Bump to version 0.8.1
- Bug fixes:
  - Make sure registry volume is not left in /etc/fstab
  - Fix EPEL repository enablement
  - Explicitly set replica=1 for registry

* Wed Sep 14 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.8.0-1
- Bump to version 0.8.0
- Switch to Ansible 2.1
- Improve scalability (up to 100 nodes)
- Use IP failover for OpenShift router
- Add subscription manager register to satellite
- Evacuate pods before removing a node
- Automatic subscription removal
- Allow setting quotas on container and emptyDir volumes
- Allow use of external volume for registry storage

* Thu Jun 16 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.7.0-1
- Bump to version 0.7.0

* Thu Jun 02 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.6.0-1
- Bump to version 0.6.0

* Fri May 13 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.5.0-1
- Bump to version 0.5.0

* Tue Mar 22 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.4.0-1
- Bump to version 0.4.0
- Enable dedicated loadbalancer node (again)

* Tue Mar 22 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.3.0-1
- Bump to version 0.3.0

* Fri Feb 19 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.2.0-1
- Bump to version 0.2.0

* Wed Jan 27 2016 Sylvain Baubeau <sbaubeau@redhat.com> - 0.1.0-1
- Initial openshift-on-openstack rpm
