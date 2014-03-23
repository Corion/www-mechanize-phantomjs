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
    plan tests => 5;
};

isa_ok $mech, 'WWW::Mechanize::PhantomJS';

my $html = $mech->content;
like $html, qr!<html><head></head><body></body></html>!, "We can get the plain HTML";

my $html2 = $mech->content( format => 'html' );
is $html2, $html, "When asking for HTML explicitly, we get the same text";

my $text = $mech->content( format => 'text' );
is $text, '', "We can get the plain text";

my $text2;
my $lives = eval { $mech->content( format => 'bogus' ); 1 };
ok !$lives, "A bogus content format raises an error";
