
# Sys-Utmp-DB Makefile.PL
# $Id$

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'Sys::Utmp::DB',
	VERSION_FROM => 'lib/Sys/Utmp/DB.pm',
	EXE_FILES => [
		"bin/utmpdmp",
		"bin/utmpproc",
		"bin/utmpdb"
	],
	PREREQ_PM => {
		'Sys::Utmp' => 1.7, # tested against 1.7
		'DBD::SQLite' => 1.3, # tested against 1.35
		'YAML' => 0 # tested against 0.84
	}
);

