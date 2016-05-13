#! /usr/bin/env perl

#
# Sys::Utmp::Processor
# ====================
#
# $Id$
#
# Sys::Utmp event-emitting processor gizmo.
#
# Basically, this class serves as a higher-level interface to Sys::Utmp,
# synthesizing 'session' records from the individual utmp login/logout
# records returned from Sys::Utmp.
#
# TODO: Actually document usage, meaning of different records:
#
#    - normal/active/<reboot|shutdown|linuxfoo>
#
# Some limitations:
#
#   - In the event of crashes logout time is assumed to be the 
#     system restart time which is obviously incorrect, and more so incorrect 
#     for sustained downtimes.
#
#   - Some attempt is made at determining 'still active' user logins,
#     however this can be problematic if the user has been forcably
#     disconnected. In this case, since no logout record exists,
#     the user will still appear logged in. Additionally, 'dangling'
#     records will then result in skewed login durations after a system reboot,
#     since their logout time will be subsequently assumed to be the system
#     restart time.
#
#   - The only way to handle disconnect records 'properly' would be to 
#     secondarily inspect the live system state, which makes processing
#     much more difficult, and doesn't solve the compounded secondary 
#     problem of 'dangling logins' after a reboot. Therefore, no attempt
#     is made to fix these issues. Progams wishing to have a precise
#     notion of duration should either synthesize their own closing records,
#     rely solely on the more accurate login records.
#
#   - The module doesn't handle records split across multiple files -
#     as the processing logic relies on end-of-file in the underlying wtmp
#     object to terminate state.
#
# Platform-Specific Notes
# -----------------------
#
# BSD-Derived Systems
# ~~~~~~~~~~~~~~~~~~~
#
# Tested against OpenBSD 5.6 which has a traditional 4.4BSD utmp(5).
#
# - all records are $utent->user_process() == 1
# - have to call 'new,utmpname,setutent' to properly select an alternate file.
#
# Basically, as can be seen from the last(1) output in the __DATA__
# section of the file and the utmp(5) page:
#
#   - user login records are created when users login
#   - logout timestamps are created when users logout
#   - shutdown records are created on clean shutdown
#   - reboot records are created on system startup
#
# Therefore, user records can show:
#
#   - active login
#   - normal login/logout duration
#   - login interrupted by scheduled reboot (-shutdown)
#   - login interrupted by unscheduled reboot (-crash)
#
# and so actual logged-in time can be roughly interpolated.
#
# Linux Systems
# ~~~~~~~~~~~~~
#
# Linux uses a synthetic format, taking elements of the OSF utmpx
# record type, and also the traditional BSD utmp records type.
#
# For the most part, the result is the same as the BSD record system,
# however, some additional metadata is recorded, such as SysV-style
# runlevel transitions, etc.
#
# Fixme: discussion of what to filter out to ignore system events
#
# SysV Systems
# ~~~~~~~~~~~~
#
# Currently, no support is available for utmpx-format systems,
# such as Sun Solaris, due to a limitation in the underlying
# Sys::Utmp module.
#
# 

package Sys::Utmp::Processor;

use warnings;
use strict;

use Sys::Utmp;

# predecls
sub new;
sub open;
sub next;

# subs

sub new {
	my $class = shift;
	my $file = shift;
	my $self = {};

	$self->{fname} = undef;
	$self->{fproc} = undef;

	$self->{ins} = {};
	$self->{recs} = [];
	$self->{pend} = [];

	bless $self, $class;
	return $self;
}

sub open {
	my $self = shift;
	my $fname = shift;
	my $fproc = $self->{fproc};

	if(!$fproc) {
		$fproc = Sys::Utmp->new();
		$self->{fproc} = $fproc;
	}

	$fproc->utmpname($fname);
	$self->{fname} = $fname;

	$fproc->setutent();
}

sub next { # return next complete login/logout record
	my $self = shift;

	my $ret = undef;
	my $rec = undef;

	my $ins = $self->{ins};
	my $recs = $self->{recs};
	my $pend = $self->{pend};

	my $fproc = $self->{fproc};

	# look for a login/logout pair
	# take first pending if avail, update recslist, and return
	# otherwise loop on records
	#   adding logins
	#   checking logouts against logins, queueing matches
	#   checking reboots against logins,
	#     flushing logins and queing matches
	# if no more records, and queue is empty, return undef;

	while(1) {
		if (scalar @{$pend} > 0) {
			$ret = shift @{$pend};
			push @{$recs}, $ret;
			return $ret;
		}

		my $rec = $fproc->getutent();
		
		if(!$rec) { # no more records in file
		
			# handle still-logged-in users
			my ($l,$in) = each %{$ins};

			if($l) {

				$ret = {
					'user' => $in->ut_user(),
					'line' => $in->ut_line(),
					'in' => $in->ut_time(),
					'out' => 0,
					'type' => 'active'

				};
				delete $ins->{$l};

				return $ret;
			}
			
			return undef; # no records, no active logins
		}

		my $line = $rec->ut_line();

		if($line ne '~') { # user login/logout

			if($rec->ut_user()){ # login
				$ins->{$line} = $rec;
			}
			else { # logout
				my $in = $ins->{$line};
				next unless $in;
				$ret = {
					'user' => $in->ut_user(),
					'line' => $line,
					'in' => $in->ut_time(),
					'out' => $rec->ut_time(),
					'type' => 'normal'
				};
				delete $ins->{$line};
				return $ret;
			}
		}

		else { # shutdown(clean)/reboot(unclean)

			my $type = $rec->ut_user(); # reboot/shutdown

			while (my ($l,$in) = each %{$ins} ) {
				my $inrec = {
					'user' => $in->ut_user(),
					'line' => $in->ut_line(),
					'in' => $in->ut_time(),
					'out' => $rec->ut_time(),
					'type' => $type
				};
				push @{$pend}, $inrec;
			}
			$self->{ins} = $ins = {};
		}
	}
}

1;

