#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;

use WWW::Mechanize::WebDriver;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $mech = eval { WWW::Mechanize::WebDriver->new( 
    autodie => 1,
    launch_exe => 'phantomjs-versions\phantomjs-1.9.7-windows\phantomjs',
    launch_arg => ['ghostdriver\src\main.js' ],
    port => 8910, # XXX
    #log => [qw[debug]],
    #on_event => 1,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to WebDriver: $@";
    exit
} else {
    plan tests => 12;
};

isa_ok $mech, 'WWW::Mechanize::WebDriver';

sub load_file_ok {
    my ($htmlfile,@options) = @_;
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

load_file_ok('49-mech-get-file.html', javascript => 0);
$mech->get('about:blank');
load_file_ok('49-mech-get-file.html', javascript => 1);
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


undef $mech;