#!perl -w
use strict;
use WWW::Mechanize::PhantomJS;

my $mech = WWW::Mechanize::PhantomJS->new(
    launch_arg => ['ghostdriver/src/main.js' ],
);


$mech->get_local('links.html');

print $mech->eval_in_page(<<'JS');
    ["Just","another","Perl","Hacker"].join(" ");
JS

=head1 NAME

javascript.pl - execute Javascript in a page

=head1 SYNOPSIS

javascript.pl

=head1 DESCRIPTION

B<This program> demonstrates how to execute simple
Javascript in a page.

=cut