package # hide from CPAN indexer
    t::helper;
use strict;
use Test::More;
use File::Glob qw(bsd_glob);
use Config '%Config';
use File::Spec;

sub browser_instances {
    my ($filter) = @_;
    $filter ||= qr/^/;
    my @instances;
    # default PhantomJS instance
    my ($default)=
        map { my $exe= File::Spec->catfile($_,"phantomjs$Config{_exe}");
              -x $exe ? $exe : ()
            } File::Spec->path();
    push @instances, $default
        if $default;
    
    # add author tests with local versions
    my $spec = $ENV{TEST_WWW_MECHANIZE_PHANTOMJS_VERSIONS}
             || 'phantomjs-versions/*/phantomjs*'; # sorry, likely a bad default
    push @instances, sort {$a cmp $b} grep { -x } bsd_glob $spec;
    
    grep { ($_ ||'') =~ /$filter/ } @instances;
};

sub default_unavailable {
    !scalar browser_instances
};

sub run_across_instances {
    my ($instances, $port, $new_mech, $code) = @_;
    
    for my $browser_instance (@$instances) {
        if ($browser_instance) {
            diag sprintf "Testing with %s",
                $browser_instance;
        };
        my @launch = $browser_instance
                   ? ( launch_exe => $browser_instance,
                       port => $port )
                   : ();
        
        my $mech = $new_mech->(@launch);
        diag sprintf "PhantomJS version '%s', ghostdriver version '%s'",
            $mech->phantomjs_version, $mech->ghostdriver_version;

        # Run the user-supplied tests
        $code->($browser_instance, $mech);
        
        # Quit in 500ms, so we have time to shut our socket down
        undef $mech;
        sleep 2; # So the browser can shut down before we try to connect
        # to the new instance
    };
};

1;