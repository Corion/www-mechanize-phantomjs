#!perl -w
use strict;
use Test::More;
use File::Basename;
use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $mech = eval { WWW::Mechanize::PhantomJS->new( 
    autodie => 1,
    launch_exe => 'phantomjs-versions\phantomjs-1.9.7-windows\phantomjs',
    launch_arg => ['ghostdriver\src\main.js' ],
    port => 8910, # XXX
    #log => [qw[debug]],
    #on_event => 1,
)};

if (! $mech) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 2;
};

#line 2 "foo"
is eval { $mech->eval_in_page('bar'); 1 }, undef, "Invalid JS gives an error";
my $err = $@;
like $err, qr/\bat foo line 2\b/, "the correct location gets flagged as error";

undef $mech; # and close that tab
