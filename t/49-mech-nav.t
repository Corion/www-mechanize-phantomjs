#!perl

use warnings;
use strict;
use Test::More;

use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc', '.';
use Test::HTTP::LocalServer;

use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 3*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

my $server = Test::HTTP::LocalServer->spawn(
    # debug => 1, # Yay Travis CI
);

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, 3, sub {
    my ($browser_instance, $mech) = @_;

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
});

undef $server;
wait; # gobble up our child process status