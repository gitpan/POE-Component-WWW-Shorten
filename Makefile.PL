#use ExtUtils::MakeMaker;
use inc::Module::Install;

license 'perl';
author 'Chris Williams <chris@bingosnet.co.uk>';

WriteMakefile(
			  'NAME'	=> 'POE::Component::WWW::Shorten',
			  'PREREQ_PM' => {
					  'POE'    => 0.31,
					  'Carp'   => 0,
					  'WWW::Shorten' => 1.95,
					 },
			  'VERSION_FROM' => 'lib/POE/Component/WWW/Shorten.pm',
			  'dist' => { 'COMPRESS' => 'gzip --best' },
			 );

