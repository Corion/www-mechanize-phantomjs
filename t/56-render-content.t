#!perl -w
use strict;
use Test::More;
use WWW::Mechanize::PhantomJS;
use lib 'inc', '../inc';
use File::Temp qw(tempfile);
use Test::HTTP::LocalServer;

use t::helper;

# What instances of PhantomJS will we try?
my $instance_port = 8910;
my @instances = t::helper::browser_instances();
my @tests= (
    { format => 'pdf', like => qr/^%PDF-/ },
    { format => 'png', like => qr/^.PNG/, },
    { format => 'jpg', like => qr/^......JFIF/, },
);

if (my $err = t::helper::default_unavailable) {
    plan skip_all => "Couldn't connect to PhantomJS: $@";
    exit
} else {
    plan tests => (1+@tests*2)*@instances;
};

sub new_mech {
    WWW::Mechanize::PhantomJS->new(
        autodie => 1,
        launch_arg => ['ghostdriver/src/main.js' ],
        @_,
    );
};

my @delete;
END {
    for( @delete ) {
        unlink $_
            or diag "Couldn't remove tempfile '$_': $!";
    }
};

t::helper::run_across_instances(\@instances, $instance_port, \&new_mech, sub {
    my ($browser_instance, $mech) = @_;

    isa_ok $mech, 'WWW::Mechanize::PhantomJS';
    
    $mech->get_local('50-click.html');
    for my $test ( @tests ) {
        my $format= $test->{format};
        my $content= $mech->render_content( format => $format );
        like $content, $test->{like}, "->render_content( format => '$format' )"
            or diag substr( $content, 0, 10 );
        my @delete;
        my( $tempfh,$outfile )= tempfile;
        close $tempfh;
        push @delete, $outfile;
        $mech->render_content( format => $format, filename => $outfile );
        my($res, $reason)= (undef, "Outfile '$outfile' was not created");
        if(-f $outfile) {
            if( open my $fh, '<', $outfile ) {
                local $/;
                my $content= <$fh>;
                $res= $content =~ $test->{like}
                    or $reason= "Content did not match /$test->{like}/: " . substr($content,0,10);
            } else {
                $reason= "Couldn't open '$outfile': $!";
            };
        };
        ok $res, "->render_content to file"
            or diag $reason;
    };
});
