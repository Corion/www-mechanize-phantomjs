use strict;
use WWW::Mechanize::PhantomJS;

my $mech = WWW::Mechanize::PhantomJS->new(
    launch_arg => ['ghostdriver/src/main.js' ],
);

$mech->get_local('links.html');

sleep 5;

print $_->get_attribute('href'), "\n\t-> ", $_->get_attribute('innerHTML'), "\n"
  for $mech->selector('a.download');

