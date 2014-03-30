use strict;
use WWW::Mechanize::PhantomJS;

my $mech = WWW::Mechanize::PhantomJS->new(
    launch_arg => ['ghostdriver/src/main.js' ],
);

$mech->get_local('links.html');

sleep 5;

print $_->get_attribute('href'), "\n\t-> ", $_->get_attribute('innerHTML'), "\n"
  for $mech->selector('a.download');

=head1 NAME

dump-links.pl - Dump links on a webpage

=head1 SYNOPSIS

dump-links.pl

=head1 DESCRIPTION

This program demonstrates how to read elements out of the PhantomJS
DOM and how to get at text within nodes.

=cut