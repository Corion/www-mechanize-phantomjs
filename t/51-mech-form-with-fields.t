#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $server= Test::HTTP::LocalServer->spawn;

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
        launch_arg => ['ghostdriver/src/main.js' ],
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;
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
});