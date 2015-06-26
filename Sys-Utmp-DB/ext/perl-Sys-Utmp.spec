# $Id$

Name: perl-Sys-Utmp
Version: 1.7
Release: 1
Summary: OO Perl interface to utmp(5) records
License: Artistic/GPL
Group: Development/Libraries
URL: http://search.cpan.org/dist/Sys-Utmp
Source0: http://www.cpan.org/modules/by-module/Sys/Sys-Utmp-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildRequires: perl(ExtUtils::MakeMaker)
BuildRequires: perl(Test::Simple)
Requires: perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
Sys::Utmp - Object(ish) Interface to utmp files.

%prep
%setup -q -n Sys-Utmp-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
rm -rf %{buildroot}

make pure_install PERL_INSTALL_ROOT=%{buildroot}

find %{buildroot} -type f -name .packlist -exec rm -f {} \;
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null \;
find %{buildroot} -type f -name '*.bs' -size 0 -exec rm -f {} \;

%{_fixperms} %{buildroot}/*

%check
make test

%clean
rm -rf %{buildroot}

%files
%defattr(-,root,root,-)
%doc Changes
%doc examples/pwho
%{perl_vendorarch}/auto/*
%{perl_vendorarch}/Sys/*
%{_mandir}/man3/*

%changelog

* Wed Apr 22 2015  Chris Turner <cturner@rice.edu> - 1.7-1
- Initial version

