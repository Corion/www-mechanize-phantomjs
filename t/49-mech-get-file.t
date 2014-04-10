#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;

use WWW::Mechanize::PhantomJS;
use t::helper;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 12*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

sub load_file_ok {
    my ($mech, $htmlfile,@options) = @_;
    my $fn = File::Spec->rel2abs(
                 File::Spec->catfile(dirname($0),$htmlfile),
                 getcwd,
             );
    #$mech->allow(@options);
    diag "Loading $fn";
    $mech->get_local($fn);
    ok $mech->success, $htmlfile;
    is $mech->title, $htmlfile, "We loaded the right file (@options)"
        or diag $mech->content;
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($firefox_instance, $mech) = @_;

    isa_ok $mech, 'WWW::Mechanize::PhantomJS';


    load_file_ok($mech, '49-mech-get-file.html', javascript => 0);
    $mech->get('about:blank');
    load_file_ok($mech, '49-mech-get-file.html', javascript => 1);
    $mech->get('about:blank');

    $mech->get_local('49-mech-get-file.html');
    ok $mech->success, '49-mech-get-file.html';
    is $mech->title, '49-mech-get-file.html', "We loaded the right file";

    ok $mech->is_html, "The local file gets identified as HTML"
        or diag $mech->content;

    $mech->get_local('49-mech-get-file-lc-ct.html');
    ok $mech->success, '49-mech-get-file-lc-ct.html';
    is $mech->title, '49-mech-get-file-lc-ct.html', "We loaded the right file";

    ok $mech->is_html, "The local file gets identified as HTML even with a weird-cased http-equiv attribute"
        or diag $mech->content;

    $mech->get_local('file-does-not-exist.html');
    ok !$mech->success, 'We fail on non-existing file';
});
