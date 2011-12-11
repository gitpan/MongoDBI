use Test::More;

use strict;
use warnings;

plan $ENV{TEST_MONGODBI}
  ? (tests => 5)
  : (skip_all => 'TEST_MONGODBI is not set. Tests skipped.');

# test loading modules, roles, etc
sub load_class {

    my $class = shift;

    eval { require $class };

    return $@ ? 0 : 1;

}

ok !load_class('MongoDBI::Document::Base'),

  'MongoDBI::Document::Base is a role, not directly loadable';

ok !load_class('MongoDBI::Document::Config'),

  'MongoDBI::Document::Config is a role, not directly loadable';

ok !load_class('MongoDBI::Document::Storage'),

  'MongoDBI::Document::Storage is a role, not directly loadable';

ok !load_class('MongoDBI::Document::Sugar'),

  'MongoDBI::Document::Sugar is a role, not directly loadable';

ok !load_class('MongoDBI::Document::Storage::Operation'),

  'MongoDBI::Document::Storage::Operation is a role, not directly loadable';
