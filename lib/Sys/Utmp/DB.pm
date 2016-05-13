
# Sys::Utmp::DB
# =============
#
# $Id$
#
# Sys::Utmp SQL-Backed login database class.
#
#

# globals

package Sys::Utmp::DB;
$VERSION = 1.0;

use warnings;
use strict;

use Carp;

use DBI;
use DBD::SQLite;

use Sys::Utmp::Processor;

# sub predecls

sub new;
sub connect;

sub createdb;
sub begintxn;
sub insertrec;
sub updaterec;
sub endtxn;

# todo: smart-insert - e.g. replace existing records with update
#   ... this is good if e.g. still logged in records are lated updated

sub main;

# subs

sub new {
	my $class = shift;
	my $fname = shift;

	my $self = {};
	$self->{dbh} = undef;
	$self->{dburi} = undef;

	if($fname) {
		Sys::Utmp::DB::connect($self,$fname) or return undef;
	}

	bless $self,$class;

	return $self;
}

sub connect {
	my($self,$fname) = @_;

	return undef unless $fname;

	my $dburi = "dbi:SQLite:$fname";
	my $dbh = DBI->connect($dburi);

	if(!$dbh) {
		carp "unable to connect to $dburi: $!\n";
		return undef;
	}

	# connection settings...
	$dbh->do('pragma journal_mode = truncate');

	$self->{dburi} = $dburi;
	$self->{dbh} = $dbh;

	return $dbh;
}

sub createdb {
	my $self = shift;

	my ($dbh,$sth);
	my $schema = join '', <DATA>;

	$dbh = $self->{dbh};

	if(!$dbh) {
		carp "createdb on unconnected object";
		return 1;
	}

	$sth = $dbh->prepare($schema);
	$sth->execute();

	return 0;
}

sub begintxn {
	my $self = shift;
	my ($dbh,$sth);

	$dbh = $self->{dbh};

	if(!$dbh) {
		carp "begintxn on unconnected object";
		return 1;
	}

	$dbh->do('begin transaction');
}

sub insertrec {
	my ($self,$rec) = @_;

	my ($dbh,$sth);

	return undef unless $rec;

	$dbh = $self->{dbh};
	$sth = $dbh->prepare("insert into utmpdata values(?,?,?,?,?,?)");

	$sth->bind_param(1, $rec->{in});
	$sth->bind_param(2, $rec->{out});
	$sth->bind_param(3, $rec->{host});
	$sth->bind_param(4, $rec->{line});
	$sth->bind_param(5, $rec->{user});
	$sth->bind_param(6, $rec->{type});

	$sth->execute();	
}

sub endtxn {
	my $self = shift;
	my $dbh = $self->{dbh};

	if(!$dbh) {
		carp "begintxn on unconnected object";
		return 1;
	}

	$dbh->do('commit');
}

1;
__DATA__

--
-- Sys::Utmp::DB SQL Schema
-- created for sqlite3 databases
--
-- $Id$
--

create table utmpdata (
	timein integer not null,
	timeout integer,
	host text not null,
	line text not null,
	user text not null,
	type text,
	primary key (timein,host,line)
);

