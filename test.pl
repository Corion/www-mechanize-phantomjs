#!perl -w
use strict;
use lib 'lib';
use Data::Dumper;
use WWW::Mechanize::WebDriver;

my $mech= WWW::Mechanize::WebDriver->new(
    launch_exe => 'phantomjs-versions\phantomjs-1.9.0-windows\phantomjs',
);
my $res= $mech->get('http://google.de');
print Dumper $res;
print $mech->title;

#print $mech->decoded_content;

    $res= $mech->get('http://doesnotexist.example.com');
print Dumper $res;

