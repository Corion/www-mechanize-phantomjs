#!perl

use warnings;
use strict;
use Test::More;

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
    my $err = $@;
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 3;
};

my $server = Test::HTTP::LocalServer->spawn();

$mech->get($server->url);

$mech->click_button(number => 1);
like( $mech->uri, qr/formsubmit/, 'Clicking on button by number' );
my $last = $mech->uri;

diag "Going back";
$mech->back;
is $mech->uri, $server->url, 'We went back';

diag "Going forward";
$mech->forward;
is $mech->uri, $last, 'We went forward';
