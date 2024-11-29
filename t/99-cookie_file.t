#!perl -w
use strict;
use Test::More tests => 1;
use File::Temp;
use WWW::Mechanize::PhantomJS;

my $tmp = File::Temp->new;
my $mech = WWW::Mechanize::PhantomJS->new( 
    cookie_file => $tmp->filename,
);
$mech->get_local('99-cookie_file.html');
ok -s $tmp->filename > 0, "cookie_file saved.";
