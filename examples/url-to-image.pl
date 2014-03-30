use strict;
use File::Spec;
use File::Basename 'dirname';
use WWW::Mechanize::PhantomJS;

my $mech = WWW::Mechanize::PhantomJS->new(
    launch_arg => ['ghostdriver/src/main.js' ],
);

sub show_screen() {
    my $page_png = $mech->content_as_png();

    my $fn= File::Spec->rel2abs(dirname($0)) . "/screen.png";
    open my $fh, '>', $fn
        or die "Couldn't create '$fn': $!";
    binmode $fh, ':raw';
    print $fh $page_png;
    close $fh;
    
    #system(qq(start "Progress" "$fn"));
};

$mech->get('http://act.yapc.eu/gpw2014');

show_screen;
