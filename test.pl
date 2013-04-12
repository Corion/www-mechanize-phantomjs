#!perl -w
use strict;
use lib 'lib';
use WWW::Mechanize::WebDriver;

my $mech= WWW::Mechanize::WebDriver->new(
    launch_exe => 'phantomjs-versions\phantomjs-1.9.0-windows\phantomjs',
);
$mech->get('http://google.de');
sleep 4;
print $mech->title;

#print $mech->decoded_content;