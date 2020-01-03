#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::PhantomJS;

use strict;
use Test::More;
use Cwd;
use URI;
use URI::file;
use File::Basename;
use File::Spec;
use File::Temp 'tempdir';

use lib '.';

use t::helper;

# What instances of PhantomJS will we try?
my @instances = t::helper::browser_instances();
my $instance_port = 8910;

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => 7*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        @_,
    );
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, 7, sub {
    my ($browser_instance, $mech) = @_;
    isa_ok $mech, 'WWW::Mechanize::PhantomJS';

    $mech->get_local('51-mech-links-nobase.html');
    

    my @found_links = $mech->links;
    # There is a FRAME tag, but FRAMES are exclusive elements
    # so PhantomJS ignores it while WWW::Mechanize picks it up
    if (! is scalar @found_links, 5, 'All 5 links were found') {
        diag sprintf "%s => %s", $_->tag, $_->url
            for @found_links;
    };

    $mech->get_local('51-mech-links-base.html');

    @found_links = $mech->links;
    SKIP: {
            my @wanted_links = @found_links;

            if( ! is scalar @wanted_links, 2, 'The two links were found') {
                diag $_->url for @found_links;
                diag $_->url_abs for @found_links;
            };
            my $url = URI->new_abs($found_links[0]->url, $found_links[0]->base);
            is $url, 'https://somewhere.example/relative',
                'BASE tags get respected';
            $url = URI->new_abs($found_links[1]->url, $found_links[1]->base);
            is $url, 'https://somewhere.example/myiframe',
                'BASE tags get respected for iframes';
    }

    # There is a FRAME tag, but FRAMES are exclusive elements
    # so Firefox ignores it while WWW::Mechanize picks it up
    my @frames = $mech->selector('frame');
    is @frames, 0, "FRAME tag"
        or diag $mech->content;

    @frames = $mech->selector('iframe');
    is @frames, 1, "IFRAME tag";
});
