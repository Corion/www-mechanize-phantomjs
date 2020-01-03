#!perl
use warnings;
use strict;
use File::Find;
use Test::More;
BEGIN {
    eval 'use Capture::Tiny ":all"; 1';
    if ($@) {
        plan skip_all => "Capture::Tiny needed for testing";
        exit 0;
    };
};

plan 'no_plan';

require './Makefile.PL';
# Loaded from Makefile.PL
our %module = get_module_info();

my $last_version = undef;

sub check {
    #return if (! m{(\.pm|\.pl) \z}xmsi);

    my ($stdout, $stderr, $exit) = capture(sub {
        system( $^X, '-Mblib', '-c', $_ );
    });

    s!\s*\z!!
        for ($stdout, $stderr);

    if( $exit ) {
        diag $stderr;
        diag "Exit code: ", $exit;
        fail($_);
    } elsif( $stderr ne "$_ syntax OK") {
        diag $stderr;
        fail($_);
    } else {
        pass($_);
    };
}

my @files;
find({wanted => \&wanted, no_chdir => 1},
    grep { -d $_ }
         'blib/lib', 'examples', 'lib'
    );

if( my $exe = $module{EXE_FILES}) {
    push @files, @$exe;
};

for (@files) {
    check($_)
}

sub wanted {
  push @files, $File::Find::name if /\.p(l|m|od)$/;
}
