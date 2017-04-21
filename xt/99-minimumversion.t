#!perl -w
use strict;
use Test::More;

eval {
  require Test::MinimumVersion::Fast;
  Test::MinimumVersion::Fast->import;
};

if ($@) {
  plan skip_all => "Test::MinimumVersion::Fast required for testing minimum Perl version";
}
else {
  all_minimum_version_from_metayml_ok();
}
