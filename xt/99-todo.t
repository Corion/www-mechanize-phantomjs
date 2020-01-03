use Test::More;
use File::Spec;
use File::Find;
use strict;

# Check that all files do not contain any
# lines with "XXX" - such markers should
# either have been converted into Todo-stuff
# or have been resolved.
# The test was provided by Andy Lester.

require './Makefile.PL';
# Loaded from Makefile.PL
our %module = get_module_info();

my @files;
my $blib = File::Spec->catfile(qw(blib lib));
find(\&wanted, grep { -d } ($blib));

if( my $exe = $module{EXE_FILES}) {
    push @files, @$exe;
};

plan tests => 2* @files;
foreach my $file (@files) {
  source_file_ok($file);
}

sub wanted {
  push @files, $File::Find::name if /\.p(l|m|od)$/;
}

sub source_file_ok {
    my $file = shift;

    open( my $fh, '<', $file ) or die "Can't open $file: $!";
    my @lines = <$fh>;
    close $fh;

    my $n = 0;
    for ( @lines ) {
        ++$n;
        s/^/$file ($n): /;
    }

    my @x = grep /XXX/, @lines;

    if ( !is( scalar @x, 0, "Looking for XXXes in $file" ) ) {
        diag( $_ ) for @x;
    }
    @x = grep /<<<|>>>/, @lines;

    if ( !is( scalar @x, 0, "Looking for <<<<|>>>> in $file" ) ) {
        diag( $_ ) for @x;
    }
}
