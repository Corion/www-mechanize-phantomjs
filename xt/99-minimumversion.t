#!perl -w
use strict;
use Test::More;

eval {
  require Test::MinimumVersion;
  Test::MinimumVersion->import;
};

if ($@) {
  plan skip_all => "Test::MinimumVersion required for testing minimum Perl version";
}
else {
  all_minimum_version_from_metayml_ok();
}
