#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use Data::Dumper;

use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use t::helper;

my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 6*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

sub load_file_ok {
    my ($mech, $htmlfile,@options) = @_;
    $mech->clear_js_alerts;
    $mech->allow(@options);
    $mech->get_local($htmlfile);
    ok $mech->success, $htmlfile;
    is $mech->title, $htmlfile, "We loaded the right file (@options)";
};

t::helper::run_across_instances(\@instances, undef, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;
    isa_ok $mech, 'WWW::Mechanize::PhantomJS';
    can_ok $mech, 'confirm';

    $mech->confirm( 'a'  );
    $mech->confirm( b => 1 );
    $mech->confirm( c => 0 );

    load_file_ok($mech, '59-confirm.html', javascript => 1);

    my @res= $mech->js_alerts;
    ok( 4 == @res, "got four responses");
    ok( join(' ', @res) eq 'true true false false', "confirms are ok");
});
