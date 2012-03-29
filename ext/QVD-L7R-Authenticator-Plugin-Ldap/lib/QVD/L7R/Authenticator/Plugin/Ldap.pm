package QVD::L7R::Authenticator::Plugin::Ldap;

our $VERSION = '0.01';

use warnings;
use strict;

use QVD::Config;
use QVD::Log;
use Net::LDAP qw(LDAP_SUCCESS LDAP_INVALID_CREDENTIALS);
use parent qw(QVD::L7R::Authenticator::Plugin);

my $ldap_host   = cfg('auth.ldap.host');
my $ldap_base   = cfg('auth.ldap.base');
my $ldap_filter = cfg('auth.ldap.filter', 0) // '(uid=%u)';
my $ldap_scope  = cfg('auth.ldap.scope' , 0) // 'base';
my $ldap_binddn = cfg('auth.ldap.binddn', 0) // '';
my $ldap_bindpass = cfg('auth.ldap.bindpass', 0) // '';
my $ldap_userbindpattern = cfg('auth.ldap.userbindpattern', 0) // '';
my $ldap_deref = cfg('auth.ldap.deref', 0) // 'never';
my $ldap_racf_regex = cfg('auth.ldap.racf_allowregex', 0);

$ldap_scope =~ /^(?:base|one|sub)$/ or die "bad value $ldap_scope for auth.ldap.scope";
$ldap_deref =~ /^(?:never|search|find|always)$/ or die "bad value $ldap_deref for auth.ldap.deref";

sub _escape {
    # This sub formerly copied from Net::LDAP::Filter
    # Copyright (c) 1997-2004 Graham Barr.
    my $str = shift;
    $str =~ s/([\\\(\)\*\0-\37\177-\377])/sprintf("\\%02x",ord($1))/sge;
    $str
}

sub authenticate_basic {
    my ($class, $auth, $login, $passwd, $l7r) = @_;
    my $ldap = Net::LDAP->new($ldap_host)
	// die "Unable to connect to LDAP server $ldap_host for user $login: $@\n";

    my $escaped_login = _escape($login);

    if ($ldap_userbindpattern ne '') {
	$ldap_userbindpattern =~ s/\%u/$escaped_login/g;
	DEBUG("auth.ldap.userbindpattern provided trying login with <$ldap_userbindpattern> for user $login");
	my $msg = $ldap->bind($ldap_userbindpattern, password => $passwd);
	if (!$msg->code) {
	    DEBUG("auth.ldap.userbindpattern login with <$ldap_userbindpattern> was success for user $login");
	    return 1;
	}
	DEBUG("auth.ldap.userbindpattern login with <$ldap_userbindpattern> failed, continuing next bit for user $login");
    }

    $ldap_binddn =~ s/\%u/$escaped_login/g;
    if ($ldap_bindpass eq '' && $ldap_binddn ne '') {
	DEBUG("auth.ldap.bindpass was empty using session password for user <$ldap_binddn> for user $login");
	$ldap_bindpass = $passwd 
    }
    my $msg = ($ldap_binddn eq '')
	? $ldap->bind
	: $ldap->bind($ldap_binddn, password=>$ldap_bindpass);

    DEBUG("Binding as <$ldap_binddn> for user $login");
    $msg->code and die "LDAP bind failed: " . $msg->error . "\n";

    my $filter = $ldap_filter;
    $filter =~ s/\%u/$escaped_login/g;
    $msg = $ldap->search(base   => $ldap_base,
			 filter => $filter,
			 deref => $ldap_deref,
	);
    DEBUG("searching in $ldap_base with filter $filter for user $login");
    if (!$msg->code) {
	if (defined (my $entry = ($msg->entries)[0])) {
	    my $dn = $entry->dn;
	    DEBUG("Found DN $dn for for user $login");
	    $msg = $ldap->bind($dn, password => $passwd);
	    if (!$msg->code) {
		return 1;
	    } else {
		# TODO check for $msg->code failed credentials (49) LDAP_INVALID_CREDENTIALS (49) from LDAP::Constant
		if (defined($ldap_racf_regex) && $msg->code == LDAP_INVALID_CREDENTIALS && 
		    defined($msg->server_error) && $msg->server_error =~ /$ldap_racf_regex/) {
		    INFO "Authenticating user $escaped_login with error code invalid credentials but matching RACF Extension <$ldap_racf_regex>";
		    return 1;
		}
		DEBUG "Error in authentication. Ldap code was: ".$msg->code."(".$msg->error_desc.").".
		    ((defined $msg->server_error) ? " Server error:".$msg->server_error : "");
	    }
	} else {
		DEBUG "Error no entry found for $ldap_base with filter $filter for user $login";
	}
    } else {
	ERROR "Error in DN search $ldap_base with filter $filter for user $login. Ldap code was: ".$msg->code."(".$msg->error_desc.")";
    }
    return ()
}


1;

__END__

=head1 NAME

QVD::L7R::Authenticator::Plugin::Ldap - LDAP Authentication plugin


=head1 DESCRIPTION

This module is used to authenticate users against an LDAP directory.

This module is commonly used with the QVD::L7R::Authenticator::Plugin::Auto
plugin.

=head2 EXAMPLE

An example configuration would be:

 qvd-admin.pl config set l7r.auth.plugins=ldap
qvd-admin.pl config set auth.ldap.host=ds.theqvd.com
qvd-admin.pl config set auth.ldap.base=ou=People,dc=theqvd,dc=com

Another example configuration would be (including the auto config):

 qvd-admin.pl config set l7r.auth.plugins=auto,ldap
qvd-admin.pl config set auth.ldap.host=ldaps://ds.theqvd.com:1636
qvd-admin.pl config set auth.ldap.base=ou=People,dc=theqvd,dc=com
qvd-admin.pl config set auth.ldap.scope=sub
qvd-admin.pl config set auth.ldap.filter=(&(objectClass=inetOrgPerson)(cn=%u))
qvd-admin.pl config set auth.auto.osi_id=1

=head2 OPTIONS

To enable the plugin add "ldap" to C<l7r.auth.plugins>. And the following configuration
items:

=over 4

=item * auth.ldap.host (Required). Can be a host or an LDAP uri as specified in Net::LDAP

=item * auth.ldap.base (Required). The search base where to find the users with the
auth.ldap.filter (see below)

=item * auth.ldap.filter (Optional by default '(uid=%u)'). The string %u will be
substituted with the login name

=item * auth.ldap.binddn (Optional by default empty). The initial bind to find the users.
By default the initial bind is done as anonymous unless this parameter is specified. If 
it contains the string %u, that is substituted with the login

=item * auth.ldap.bindpass (Optional by default empty). The password for the binddn

=item * auth.ldap.scope (Optional by default 'base'). See the Net::LDAP scope attribute
in the search operation. If this is empty the password provided in during
the authentication is used

=item * auth.ldap.userbindpattern (Optional by default empty). If specified an initial
bind with this string is attempted. The login attribute is susbsituted with %u.

=item * auth.ldap.deref (Optional by default never). How aliases are dereferenced, the
accepted values are never, search, find and always. See L<Net::LDAP> for more info.

=item * auth.ldap.racf_allowregex (Optional by default not set). This is a regex to allow
to authenticate some RACF error codes. An example setting would be "^R004109 ".
One of the common cases is R004109 which returns an ldap code 49 (invalid credentials)
and a text message such as "R004109 The password has expired 
(srv_authenticate_native_password))". If you don't have RACF this is probably not for you.
Example RACF errors:

=over 4

=item * R004107 The password function failed; not loaded from a program controlled library.

=item * R004108 TDBM backend password API resulted in an internal error.

=item * R004109 The password has expired.

=item * R004110 The userid has been revoked.

=item * R004128 Native authentication password change failed. The new password is not
valid or does not meet requirements.

=item * R004111 The password is not correct.

=item * R004112 A bind argument is not valid.

=item * R004118 Entry native user ID (ibm-nativeId,uid) is not defined to the Security Server.

=back

=back

=head2 AUTHENTICATCION ALGORITHM

The authentication algorith is as follows:

=over 4

=item * If auth.ldap.userbindpattern is defined then a bind is tried with this DN
subsitutiting %u with the login. If it is successful the user is authenticated and 
if it fails the following steps are attempted

=item * A bind as anonymous user (if auth.ldap.binddn is not defined, if not a bind
as that user is done) and search for the user dn, with the search path specified in
auth.ldap.base and the user filter specified as auth.ldap.filter. The
auth.ldap.filter gets substituted %u with the login name. If no user is found
authentication fails.

=item * If a userdn is found a bind with that user is tried.

=back

=head1 METHODS

=head2 authenticate_basic

Main authentication function. The parameters received are:

=over 4

=item $self. The QVD::L7R::Authenticator::Plugin::Ldap object

=item $auth. The QVD::L7R::Authenticator object this object usually stores the login and
other common information

=item $login. The username

=item $passwd. The password

=item $l7r. The L7R object. This is the L7R object. You can obtain the source ip address for
example with $l7r->{server}->{client}->peerhost()

=back

=cut


=head1 SEE ALSO

L<QVD::L7R::Authenticator::Plugin::Auto> and <Net::LDAP>

=head1 SUPPORT

Please contact L<http://theqvd.com> For support


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Qindel FormaciE<oacute>n y Servicios SL.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License version 3 as published
by the Free Software Foundation.

See http://dev.perl.org/licenses/ for more information.

=cut

