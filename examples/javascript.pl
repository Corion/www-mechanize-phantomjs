use strict;
use WWW::Mechanize::PhantomJS;

my $mech = WWW::Mechanize::PhantomJS->new(
    launch_arg => ['ghostdriver/src/main.js' ],
);


$mech->get_local('links.html');

print $mech->eval_in_page(<<'JS');
    ["Just","another","Perl","Hacker"].join(" ");
JS
