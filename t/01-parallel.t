#!perl -w
use strict;
use Test::More tests => 3;
use Cwd;
use URI::file;
use File::Basename;
use File::Spec;
use lib 'inc', '../inc';
use WWW::Mechanize::PhantomJS;

my $a = WWW::Mechanize::PhantomJS->new;
my $b = WWW::Mechanize::PhantomJS->new;
ok( $a, "instance 1 started" );
ok( $b, "instance 2 started") ;
ok( $a->{port} != $b->{port}, "using two different ports" ) ;
