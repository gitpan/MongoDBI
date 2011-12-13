use Test::More;

use strict;
use warnings;
 
plan $ENV{TEST_MONGODBI} ?
    (tests => 6) :
    (skip_all => 'TEST_MONGODBI is not set. Tests skipped.') ;

# test loading modules, roles, etc
sub load_class {
    
    my $class = shift;
    
    eval "require $class";
    
    return $@ ? 0 : 1;
    
}

ok load_class('MongoDBI'),

    'MongoDBI loaded';

ok load_class('MongoDBI::Application'),

    'MongoDBI::Application loaded';

ok load_class('MongoDBI::Document'),

    'MongoDBI::Document loaded';

ok load_class('MongoDBI::Document::Child'),

    'MongoDBI::Document::Child loaded';

ok load_class('MongoDBI::Document::Relative'),

    'MongoDBI::Document::Relative loaded';

ok load_class('MongoDBI::Document::Storage::Criterion'),

    'MongoDBI::Document::Storage::Criterion loaded';
