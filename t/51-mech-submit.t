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
    plan tests => 11*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        launch_arg => ['ghostdriver/src/main.js' ],
        @_,
    );
};

my $server= Test::HTTP::LocalServer->spawn;

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;
    isa_ok $mech, 'WWW::Mechanize::PhantomJS';

    $mech->get_local('51-mech-submit.html');

    my ($triggered,$type,$ok);
    eval {
        ($triggered) = $mech->eval_in_page('myevents');
        $ok = 1;
    };
    if (! $triggered) {
        SKIP: { skip "Couldn't get at 'myevents'. Do you have a Javascript blocker?", 10; };
        exit;
    };
    ok $triggered, "We have JS enabled";

    $mech->allow('javascript' => 1);
    $mech->form_id('testform');

    $mech->field('q','1');
    $mech->submit();

    ($triggered) = $mech->eval_in_page('myevents');

    is $triggered->{action}, 1, 'Action   was triggered';
    is $triggered->{submit}, 1, 'OnSubmit was not triggered';
    is $triggered->{click},  0, 'Click    was not triggered';

    $mech->get_local('51-mech-submit.html');
    $mech->allow('javascript' => 1);
    $mech->submit_form(
        with_fields => {
            r => 'Hello Firefox',
        },
    );
    ($triggered) = $mech->eval_in_page('myevents');
    ok $triggered, "We found 'myevents'";

    is $triggered->{action}, 1, 'Action   was triggered';
    is $triggered->{submit}, 1, 'OnSubmit was not triggered';
    is $triggered->{click},  0, 'Click    was not triggered';

    my $r = $mech->xpath('//input[@name="r"]', single => 1 );
    is $r->get_value, 'Hello Firefox', "We set the new value";

    $mech->get_local('51-mech-submit.html');
    $mech->allow('javascript' => 1);
    $mech->form_number(1);
    $mech->submit_form();
    ($triggered) = $mech->eval_in_page('myevents');
    ok $triggered, "We can submit an empty form";
});