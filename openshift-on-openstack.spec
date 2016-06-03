Name: openshift-on-openstack
Version: 0.6.0
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
%doc LICENSE.txt README.adoc
%{_datadir}/%{name}
%{_bindir}/customize-disk-image

%changelog
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
