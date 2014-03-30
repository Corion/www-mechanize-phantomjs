#!perl -w
use strict;
use WWW::Mechanize::PhantomJS;

my $mech = WWW::Mechanize::PhantomJS->new(
    launch_arg => ['ghostdriver/src/main.js' ],
);

for my $url (@ARGV) {
    print "Loading $url";
    $mech->get($url);

    my $fn= 'screen.pdf';
    my $page_pdf = $mech->content_as_pdf(
        filename => $fn,
    );
    print "\nSaved $url as $fn\n";
};