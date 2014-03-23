#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $mech = eval { WWW::Mechanize::PhantomJS->new( 
    autodie => 1,
    launch_exe => 'phantomjs-versions\phantomjs-1.9.2-windows\phantomjs',
    launch_arg => ['ghostdriver\src\main.js' ],
    port => 8910, # XXX
    #log => [qw[debug]],
    #on_event => 1,
)};

if (! $mech) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 5;
};

isa_ok $mech, 'WWW::Mechanize::PhantomJS';

my ($site,$estatus) = ('http://'.rand(1000).'.www.doesnotexist.example/',500);
my $res = $mech->get($site);

#is $mech->uri, $site, "Navigating to (nonexisting) $site";

if( ! isa_ok $res, 'HTTP::Response', 'The response') {
    SKIP: { skip "No response returned", 1 };
} else {
    my $c = $res->code;
    like $res->code, qr/^(404|5\d\d)$/, "GETting $site gives a 5xx (no proxy) or 404 (proxy)"
        or diag $mech->content;

    like $mech->status, qr/^(404|5\d\d)$/, "GETting $site returns a 5xx (no proxy) or 404 (proxy) HTTP status"
        or diag $mech->content;
};

ok !$mech->success, 'We consider this response not successful';