#!perl -w

use warnings;
use strict;
use Test::More;
use File::Find;

if( ! -d 'examples' ) {
    plan 'skip_all', "No examples directory found";
    exit;
};

plan 'no_plan';

sub check {
    return if (! m{\.pl \z}xms);    
    my $output = `"$^X" -c $_ 2>&1`;
    like( $output, qr/$_ syntax OK/, "$_ compiles" )
}

find({wanted => \&check, no_chdir => 1}, 'examples');
