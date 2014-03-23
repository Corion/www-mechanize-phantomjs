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
    plan tests => 9;
};

isa_ok $mech, 'WWW::Mechanize::PhantomJS';
$mech->autodie(1);

$mech->get_local('50-click.html');
$mech->allow('javascript' => 1);

my ($clicked,$type,$ok);

eval {
    ($clicked, $type) = $mech->eval_in_page('clicked');
    $ok = 1;
};

if (! $clicked) {
    SKIP: { skip "Couldn't get at 'clicked'. Do you have a Javascript blocker?", 8; };
    exit;
};

ok $clicked, "We found 'clicked'";

# Xpath
$mech->get_local('50-click.html');
$mech->allow('javascript' => 1);
$mech->follow_link( xpath => '//*[@id="a_link"]', synchronize=>0, );
($clicked,$type) = $mech->eval_in_page('clicked');
is $clicked, 'a_link', "->follow_link() with an xpath selector works";

# CSS
$mech->get_local('50-click.html');
$mech->allow('javascript' => 1);
$mech->follow_link( selector => '#a_link', synchronize=>0, );
($clicked,$type) = $mech->eval_in_page('clicked');
is $clicked, 'a_link', "->follow_link() with a CSS selector works";

# Regex
$mech->get_local('50-click.html');
$mech->allow('javascript' => 1);
$mech->follow_link( text_regex => qr/A link/, synchronize => 0 );
($clicked,$type) = $mech->eval_in_page('clicked');
is $clicked, 'a_link', "->follow_link() with a RE works";

# Non-existing link
$mech->get_local('50-click.html');
my $lives = eval { $mech->follow_link('foobar'); 1 };
my $msg = $@;
ok !$lives, "->follow_link() on non-existing parameter fails correctly";
like $msg, qr/No elements found for Button with name 'foobar'/,
    "... with the right error message";

# Non-existing link via CSS selector
$mech->get_local('50-click.html');
$lives = eval { $mech->follow_link({ selector => 'foobar' }); 1 };
$msg = $@;
ok !$lives, "->follow_link() on non-existing parameter fails correctly";
like $msg, qr/No elements found for CSS selector 'foobar'/,
    "... with the right error message";