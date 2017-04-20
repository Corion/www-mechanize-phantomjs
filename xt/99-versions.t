#!perl -w

# Stolen from ChrisDolan on use.perl.org
# http://use.perl.org/comments.pl?sid=29264&cid=44309

use warnings;
use strict;
use File::Find;
use Test::More;

plan 'no_plan';

my $last_version = undef;

sub read_file {
    open my $fh, '<', $_[0]
        or die "Couldn't read '$_[0]': $!";
    binmode $fh;
    local $/;
    <$fh>
}

sub check {
      return if (! m{blib/script/}xms && ! m{\.pm \z}xms);

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

find({wanted => \&check, no_chdir => 1}, 'blib');

if (! defined $last_version) {
      fail('Failed to find any files with $VERSION');
}
