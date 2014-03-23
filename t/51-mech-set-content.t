#!perl -w
use strict;
use Test::More;
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

my $server= Test::HTTP::LocalServer->spawn;

if (! $mech) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 2;
};

isa_ok $mech, 'WWW::Mechanize::PhantomJS';

my $content = <<HTML;
<html>
<head>
<title>Hello PhantomJS!</title>
</head>
<body>
<h1>Hello World!</h1>
<p>Hello <b>WWW::Mechanize::PhantomJS</b></p>
</body>
</html>
HTML

$mech->update_html($content);

my $c = $mech->content;
for ($c,$content) {
    s/\s+/ /msg; # normalize whitespace
    s/> </></g;
    s/\s*$//;
};

is $c, $content, "Setting the content works";

