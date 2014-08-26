#!perl

use warnings;
use strict;
use Test::More;

use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8911;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 1*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

my $server = Test::HTTP::LocalServer->spawn();

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;

    $mech->get($server->url);
    pass "We can connect to port $instance_port";
});