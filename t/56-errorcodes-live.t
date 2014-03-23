#!perl -w
use strict;
use lib 'lib';
use Data::Dumper;
use WWW::Mechanize::PhantomJS;
use Test::More tests => 6;

my $mech= WWW::Mechanize::PhantomJS->new(
    launch_exe => 'phantomjs-versions\phantomjs-1.9.7-windows\phantomjs',
    launch_arg => ['ghostdriver\src\main.js' ],
    port => 8910,
);
my $res= $mech->get('http://google.de');
isa_ok $res, 'HTTP::Response', "We get a HTTP::Response";
is $res->code, 200, "... and it is OK";

#print Dumper $res;
print $mech->title,"\n";

# Hurr...
# Check a 404 response

my $url= 'http://corion.net/doesnotexist';
diag "Connecting to $url";
my $lived= eval {
    $res= $mech->get($url);
    1;
};
is $lived, 1, "We survived a 404 response"
    or diag $@;
is $res->code, 404, "We got a 404"
    or diag Dumper $res;

# Check a DNS failure (should become a 5xx response)
$url= 'http://doesnotexist.example.com';
diag "Connecting to $url";
$lived= eval {
    $res= $mech->get($url);
    1;
};
is $lived, 1, "We survived a DNS failure"
    or diag $@;
is $res->code, 500, "We got a 5xx"
    or diag Dumper $res;
diag $res->status_line;