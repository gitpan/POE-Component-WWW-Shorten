# $Id: Makefile.PL,v 3.9 2005/04/14 19:23:16 chris Exp $

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
			  'NAME'	=> 'POE::Component::WWW::Shorten',
			  'PREREQ_PM' => {
							  'POE'    => 0.31,
							  'Carp'   => 0,
							  'WWW::Shorten' => 1.95,
							 },
			  'VERSION_FROM' => 'lib/POE/Component/WWW/Shorten.pm', # finds $VERSION
			  'dist' => { 'COMPRESS' => 'gzip --best' },
			 );

