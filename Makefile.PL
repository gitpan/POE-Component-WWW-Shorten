use inc::Module::Install;
name 'POE-Component-WWW-Shorten';
license 'perl';
author 'Chris Williams <chris@bingosnet.co.uk>';
version_from 'lib/POE/Component/WWW/Shorten.pm';
requires 'Carp' => 0;
requires 'POE' => 0.38;
requires 'WWW::Shorten' => 1.95;
WriteAll();
