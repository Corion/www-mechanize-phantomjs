#!perl -w
use strict;
use Test::More;
use File::Basename;
use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use Test::HTTP::LocalServer;

use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 2*@instances;
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


#line 2 "foo"
    is eval { $mech->eval_in_page('bar'); 1 }, undef, "Invalid JS gives an error";
    my $err = $@;
    like $err, qr/\bat foo line 2\b/, "the correct location gets flagged as error";

    undef $mech; # and close that tab
});