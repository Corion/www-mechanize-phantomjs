#!perl -w
use strict;
use Test::More;
use File::Basename;

#use WWW::Mechanize::Firefox::DSL;
BEGIN {
    my $err;
    require WWW::Mechanize::PhantomJS::DSL;
    my $ok = eval { 
        WWW::Mechanize::PhantomJS::DSL->import(
            autodie => 1,
            launch_exe => 'phantomjs-versions\phantomjs-1.9.7-windows\phantomjs',
            launch_arg => ['ghostdriver\src\main.js' ],
            port => 8910, # XXX
        );
        1
    };
    $err ||= $@;
    
    if (!$ok || $err) {
        plan skip_all => "Couldn't connect to PhantomJS: $@";
        exit
    } else {
        plan tests => 2;
    };
};


get_local '49-mech-get-file.html';
is title, '49-mech-get-file.html', 'We opened the right page';
is ct, 'text/html', "Content-Type is text/html";
diag uri;

undef $mech;