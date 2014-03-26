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

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 19*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        launch_arg => ['ghostdriver/src/main.js' ],
        @_,
    );
};

sub load_file_ok {
    my ($mech, $htmlfile,@options) = @_;
    $mech->clear_js_errors;
    $mech->allow(@options);
    $mech->get_local($htmlfile);
    ok $mech->success, $htmlfile;
    is $mech->title, $htmlfile, "We loaded the right file (@options)";
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;
    isa_ok $mech, 'WWW::Mechanize::PhantomJS';
    can_ok $mech, 'js_errors','clear_js_errors';


    $mech->clear_js_errors;
    is_deeply [$mech->js_errors], [], "No errors reported on page after clearing errors"
        or diag Dumper [$mech->js_errors];

    load_file_ok($mech, '53-mech-capture-js-noerror.html', javascript => 1);
    my ($js_ok) = eval { $mech->eval_in_page('js_ok') };
    if (! $js_ok) {
        SKIP: { skip "Couldn't get at 'js_ok' variable. Do you have a Javascript blocker enabled for file:// URLs?", 14; };
        undef $mech;
        exit;
    };

    # Filter out the stupid Firefox warning about document.inputEncoding being
    # deprecated. If you deprecate it, also mark it in your documentation as
    # deprecated, and also document what to use instead!
    sub filter {
        grep { $_->{message} !~ /inputEncoding/ }
        @_
    };

    my @res= filter( $mech->js_errors );
    is_deeply \@res, [], "No errors reported on page"
        or diag $res[0]->{message};

    load_file_ok($mech, '53-mech-capture-js-noerror.html', javascript => 1 );
    @res= filter( $mech->js_errors );
    is_deeply \@res, [], "No errors reported on page";

    load_file_ok($mech,'53-mech-capture-js-error.html', javascript => 0);
    @res= filter( $mech->js_errors );
    is_deeply \@res, [], "Errors on page"
        or diag Dumper \@res;

    load_file_ok($mech,'53-mech-capture-js-error.html', javascript => 1);
    my @errors = filter( $mech->js_errors );
    is scalar @errors, 1, "One error message found";
    (my $msg) = @errors;
    like $msg->{message}, qr/^ReferenceError: Can't find variable: nonexisting_function/, "Errors message";
    like $msg->{trace}->[0]->{file}, qr!\Q53-mech-capture-js-error.html\E!, "File name";
    is $msg->{trace}->[0]->{line}, 6, "Line number";

    $mech->clear_js_errors;
    is_deeply [filter( $mech->js_errors )], [], "No errors reported on page after clearing errors";

    undef $mech; # global destruction ...
    
});