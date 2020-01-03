use Test::More;

# Check that all released module files are in
# UNIX text format

use File::Spec;
use File::Find;
use strict;

my @files = ('Makefile.PL', 'MANIFEST', 'MANIFEST.SKIP', glob 't/*.t');

require './Makefile.PL';
# Loaded from Makefile.PL
our %module = get_module_info();

my @files;
my $blib = File::Spec->catfile(qw(blib lib));
find(\&wanted, grep { -d } ($blib));

if( my $exe = $module{EXE_FILES}) {
    push @files, @$exe;
};

plan tests => scalar @files;
foreach my $file (@files) {
  unix_file_ok($file);
}

sub wanted {
  push @files, $File::Find::name if /\.p(l|m|od)$/;
}

sub unix_file_ok {
  my ($filename) = @_;
  local $/;
  open my $fh, '<', $filename
    or die "Couldn't open '$filename' : $!\n";
  binmode $fh;
  my $content = <$fh>;

  my $i;
  my @lines = grep { /\x0D\x0A$/sm } map { sprintf "%s: %s\x0A", $i++, $_ } split /\x0A/, $content;
  unless (is(scalar @lines, 0,"'$filename' contains no windows newlines")) {
    diag $_ for @lines;
  };
  close $fh;
};
