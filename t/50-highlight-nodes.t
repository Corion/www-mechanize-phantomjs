#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::PhantomJS;
use File::Temp 'tempfile';
use lib 'inc', '../inc';
use Test::HTTP::LocalServer;

use lib 'inc', '../inc';
use Test::HTTP::LocalServer;
use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 2*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        launch_arg => ['ghostdriver\src\main.js' ],
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;

    isa_ok $mech, 'WWW::Mechanize::PhantomJS';
    $mech->autodie(1);

    $mech->get_local('50-click.html');
    $mech->highlight_node($mech->selector('div'));

    my @highlighted= $mech->xpath(q{//*[contains(@style,"background-color: red;")]});
    is 0+@highlighted, 1, "We highlighted one element";

    # We should check that there now are red pixels...
    #my $fn= show_screen($mech);
});

my @delete;
sub show_screen {
    my( $mech )= @_;
    my $page_png = $mech->content_as_png();
    
    my( $fh, $fn )= tempfile();
    binmode $fh, ':raw';
    print $fh $page_png;
    close $fh;
    
    rename "$fn" => "$fn.png";
    return "$fn.png";
};
END {
    for my $file (@delete) {
        unlink $file
            or warn "Couldn't delete '$file': $!";
    }
}