use strict;
use Test::More;

# Check that MANIFEST and MANIFEST.skip are sane :

use File::Find;
use File::Spec;

my @files = qw( MANIFEST MANIFEST.SKIP );
plan tests => scalar @files * 4
              +1 # MANIFEST existence check
              +1 # MYMETA.* non-existence check
              ;

for my $file (@files) {
  ok(-f $file, "$file exists");
  open my $fh, '<', $file
    or die "Couldn't open $file : $!";
  my @lines = <$fh>;
  is_deeply([grep(/^$/, @lines)],[], "No empty lines in $file");
  is_deeply([grep(/^\s+$/, @lines)],[], "No whitespace-only lines in $file");
  is_deeply([grep(/^\s*\S\s+$/, @lines)],[],"No trailing whitespace on lines in $file");

  if ($file eq 'MANIFEST') {
    chomp @lines;
    is_deeply([grep { s/\s.*//; ! -f } @lines], [], "All files in $file exist")
        or do { diag "$_ is mentioned in $file but doesn't exist on disk" for grep { ! -f } @lines };

    # Exclude some files from shipping
    is_deeply([grep(/^MYMETA\.(yml|json)$/, @lines)],[],"We don't try to ship MYMETA.* $file");
  };

  close $fh;
};

