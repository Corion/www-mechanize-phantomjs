#!perl

use warnings;
use strict;
use Test::More;

use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc', '.';
use Test::HTTP::LocalServer;

use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8911;
my @instances = t::helper::browser_instances();

my $testcount = 3;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => $testcount*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        port => $instance_port,
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, $testcount, sub {
    my ($browser_instance, $mech) = @_;

    pass "We can connect to port $instance_port";

    SKIP: {
    skip "We now can connect twice to the same port?", 2;

    my $second_mech;
    my $lived = eval {
            $second_mech = WWW::Mechanize::PhantomJS->new(
            autodie => 1,
            port => $instance_port,
        );
        "We did connect"
    };
    is $lived, undef, "We cannot use the same port a second time";
    is $second_mech, undef, "We cannot use the same port a second time";
    }
});

