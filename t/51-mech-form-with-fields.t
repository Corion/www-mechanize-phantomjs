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

my $server= Test::HTTP::LocalServer->spawn;

if (! $mech) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 5;
};

isa_ok $mech, 'WWW::Mechanize::PhantomJS';

$mech->get_local('51-mech-submit.html');
my $f = $mech->form_with_fields(
   'r',
);
ok $f, "We found the form";

$mech->get_local('51-mech-submit.html');
$f = $mech->form_with_fields(
   'q','r',
);
ok $f, "We found the form";

SKIP: {
    skip "PhantomJS / Selenium frame support is wonky.", 2;
    
    $mech->get_local('52-frameset.html');
    $f = $mech->form_with_fields(
       'baz','bar',
    );
    ok $f, "We found the form in a frame";

    $mech->get($server->local('52-iframeset.html'));
    $f = $mech->form_with_fields(
       'baz','bar',
    );
    ok $f, "We found the form in a frame";
};