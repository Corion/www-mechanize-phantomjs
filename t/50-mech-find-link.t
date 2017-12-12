#!perl -w
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
    plan tests => 2*@instances;
};

#my $server = Test::HTTP::LocalServer->spawn(
#    #debug => 1
#);

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, 2, sub {
    my ($browser_instance, $mech) = @_;

    isa_ok $mech, 'WWW::Mechanize::PhantomJS';
	$mech->get_local("50-form2.html");

	my $link = $mech->find_link( text_regex => qr/\(1800\)/ ); # get all the links
	isa_ok $link, 'WWW::Mechanize::Link', "We found a link";
});

wait; # gobble up our child process status