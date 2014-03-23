#!perl -w
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
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 6;
};

isa_ok $mech, 'WWW::Mechanize::PhantomJS';

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);

my ($site,$estatus) = ($server->url,200);
my $res = $mech->get($site, no_cache => 1);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

is $res->code, $estatus, "GETting $site returns HTTP code $estatus from response"
    or diag $mech->content;

is $mech->status, $estatus, "GETting $site returns HTTP status $estatus from mech"
    or diag $mech->content;

ok $mech->success, 'We consider this response successful';