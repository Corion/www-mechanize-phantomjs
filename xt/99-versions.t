#!perl -w

# Stolen from ChrisDolan on use.perl.org
# http://use.perl.org/comments.pl?sid=29264&cid=44309

use warnings;
use strict;
use File::Find;
use Test::More;

require './Makefile.PL';
# Loaded from Makefile.PL
our %module = get_module_info();

my @files;
my $blib = File::Spec->catfile(qw(blib lib));
find(\&wanted, grep { -d } ($blib));

if( my $exe = $module{EXE_FILES}) {
    push @files, @$exe;
};

sub read_file {
    open my $fh, '<', $_[0]
        or die "Couldn't read '$_[0]': $!";
    binmode $fh;
    local $/;
    <$fh>
}

sub wanted {
  push @files, $File::Find::name if /\.p(l|m|od)$/;
}

plan tests => 0+@files;

my $last_version = undef;

sub check {
      my $content = read_file($_);

      # only look at perl scripts, not sh scripts
      return if (m{blib/script/}xms && $content !~ m/\A \#![^\r\n]+?perl/xms);

      my @version_lines = $content =~ m/ ( [^\n]* \$VERSION \s* = [^=] [^\n]* ) /gxms;
      if (@version_lines == 0) {
            fail($_);
      }
      for my $line (@version_lines) {
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            if (!defined $last_version) {
                  $last_version = shift @version_lines;
                  diag "Checking for $last_version";
                  pass($_);
            } else {
                  is($line, $last_version, $_);
            }
      }
}

for (@files) {
    check();
};

if (! defined $last_version) {
      fail('Failed to find any files with $VERSION');
}
