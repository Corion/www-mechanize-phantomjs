#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use lib 'inc', '../inc';
use WWW::Mechanize::PhantomJS;

use t::helper;

my @instances = t::helper::browser_instances();

if( my $err = t::helper::default_unavailable ) {
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

t::helper::run_across_instances(\@instances, undef, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;

    my $other_instance= WWW::Mechanize::PhantomJS->new(
        launch_exe => $browser_instance,
    );

    ok( $mech, "instance 1 started" );
    ok( $other_instance, "instance 2 started") ;
    ok( $mech->{port} != $other_instance->{port}, "using two different ports" ) ;
});
