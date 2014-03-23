#!perl -w
use strict;
use Test::More;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;

use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

my $mech = eval { WWW::Mechanize::PhantomJS->new( 
    autodie => 1,
    launch_exe => 'phantomjs-versions\phantomjs-1.9.7-windows\phantomjs',
    launch_arg => ['ghostdriver\src\main.js' ],
    port => 8910, # XXX
    #log => [qw[debug]],
    #on_event => 1,
)};

if (! $mech) {
    my $err = $@;
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 20;
};

my $server = Test::HTTP::LocalServer->spawn(
    #debug => 1
);


isa_ok $mech, 'WWW::Mechanize::PhantomJS';

# First get a clean check without the changed headers
my ($site,$estatus) = ($server->url,200);
my $res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

my $ua = "WWW::Mechanize::PhantomJS $0 $$";
my $ref = 'http://example.com';
$mech->add_header(
    'Referer' => $ref,
    'X-WWW-Mechanize-PhantomJS' => "$WWW::Mechanize::PhantomJS::VERSION",
    'Host' => 'www.example.com',
);

$mech->agent( $ua );

$res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";
# Now check for the changes
my $headers = $mech->selector('#request_headers', single => 1)->get_attribute('innerText');
like $headers, qr!^Referer: \Q$ref\E$!m, "We sent the correct Referer header";
like $headers, qr!^User-Agent: \Q$ua\E$!m, "We sent the correct User-Agent header";
like $headers, qr!^X-WWW-Mechanize-PhantomJS: \Q$WWW::Mechanize::PhantomJS::VERSION\E$!m, "We can add completely custom headers";
like $headers, qr!^Host: www.example.com\s*$!m, "We can add custom Host: headers";
# diag $mech->content;

$mech->delete_header(
    'X-WWW-Mechanize-PhantomJS',
);
$mech->add_header(
    'X-Another-Header' => 'Oh yes',
);

$res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

# Now check for the changes
$headers = $mech->selector('#request_headers', single => 1)->get_attribute('innerText');
like $headers, qr!^Referer: \Q$ref\E$!m, "We sent the correct Referer header";
like $headers, qr!^User-Agent: \Q$ua\E$!m, "We sent the correct User-Agent header";
unlike $headers, qr!^X-WWW-Mechanize-PhantomJS: !m, "We can delete completely custom headers";
like $headers, qr!^X-Another-Header: !m, "We can add other headers and still keep the current header settings";
# diag $mech->content;

# Now check that the custom headers go away if we uninstall them
$mech->reset_headers();

$res = $mech->get($site);
isa_ok $res, 'HTTP::Response', "Response";

is $mech->uri, $site, "Navigated to $site";

# Now check for the changes
$headers = $mech->selector('#request_headers', single => 1)->get_attribute('innerText');
#diag $headers;
unlike $headers, qr!^Referer: \Q$ref\E$!m, "We restored the old Referer header";
# ->reset_headers does not restore the UA here...
#unlike $headers, qr!^User-Agent: \Q$ua\E$!m, "We restored the old User-Agent header";
unlike $headers, qr!^X-WWW-Mechanize-PhantomJS: \Q$WWW::Mechanize::PhantomJS::VERSION\E$!m, "We can remove completely custom headers";
unlike $headers, qr!^X-Another-Header: !m, "We can remove other headers ";
# diag $mech->content;
