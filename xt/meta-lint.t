#!perl -w

# Stolen from ChrisDolan on use.perl.org
# http://use.perl.org/comments.pl?sid=29264&cid=44309

use warnings;
use strict;
use File::Find;
use Test::More;

eval {
  #require Test::MinimumVersion::Fast;
  require Parse::CPAN::Meta;
  Parse::CPAN::Meta->import();
  require CPAN::Meta::Validator;
  CPAN::Meta::Validator->VERSION(2.15);
};
if ($@) {
  plan skip_all => "CPAN::Meta::Validator version 2.15 required for testing META files";
}
else {
  plan tests => 4;
}

use lib '.';
our %module;
require 'Makefile.PL';
# Loaded from Makefile.PL
%module = get_module_info();
my $module = $module{NAME};

(my $file = $module) =~ s!::!/!g;
require "$file.pm";

my $version = sprintf '%0.2f', $module->VERSION;

for my $meta_file ('META.yml', 'META.json') {
    my $meta = Parse::CPAN::Meta->load_file($meta_file);

    my $cmv = CPAN::Meta::Validator->new( $meta );

    if(! ok $cmv->is_valid, "$meta_file is valid" ) {
        diag $_ for $cmv->errors;
    };

    # Also check that the declared version matches the version in META.*
    is $meta->{version}, $version, "$meta_file version matches module version ($version)";
};
