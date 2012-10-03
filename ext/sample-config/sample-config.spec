Name:           QVD-default-config
Version:        3.1.0
Release:        %{_svn_rev}
Summary:        QVD Default config
License:        unknown
Group:          Development/Libraries
URL:            http://svn.int.qindel.com/repos/main/projects/qindel/QVD/src/trunk/ext/sample-config
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
BuildRequires:  qvd-common-libs
Requires:       perl-QVD-L7R
Requires:       perl-QVD-HKD
Requires:       perl-QVD-Config
Requires:       perl-QVD-DB
Requires:       postgresql-server
Vendor:         QVD Team

%description
QVD default config

%prep
mkdir -p $RPM_BUILD_DIR
cd $RPM_BUILD_DIR
svn co -r %{_svn_rev} http://svn.int.qindel.com/repos/main/projects/qindel/QVD/src/trunk/ext/sample-config



%build

%install

cd $RPM_BUILD_DIR/sample-config
rm -rf $RPM_BUILD_ROOT

mkdir -p "$RPM_BUILD_ROOT/etc/qvd"
mkdir -p "$RPM_BUILD_ROOT/usr/lib/qvd/bin"

cp node.conf "$RPM_BUILD_ROOT/etc/qvd"
cp qvd-sample-init.sh "$RPM_BUILD_ROOT/usr/lib/qvd/bin"


%clean
rm -rf $RPM_BUILD_ROOT


%post

/usr/lib/qvd/bin/qvd-sample-init.sh 2>&1 | tee /var/log/qvd-sample-init.log

%files
/*

%changelog
* Tue Dec 13 2011 Qindel 3.1.0
- Specfile autogenerated by build.pl 0.1.
