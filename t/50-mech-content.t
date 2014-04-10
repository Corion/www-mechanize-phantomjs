#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 5*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;

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
});