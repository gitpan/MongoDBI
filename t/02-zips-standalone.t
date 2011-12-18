use Test::More;

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib $FindBin::Bin . '/lib';
    use lib $FindBin::Bin . '/../lib';

    plan $ENV{TEST_MONGODBI}
      ? ( tests => 8 )
      : ( skip_all => 'TEST_MONGODBI is not set. Tests skipped.' );
}

package Zips;

use MongoDBI::Document;

store 'zips';

key 'city', is_str;
key 'zip', is_int;
key 'loc', is_hash;
key 'pop', is_int;
key 'state', is_str;

filter 'in_tristate_area' => sub {
    shift->where('state$in' => ['PA','NJ','DE'])
};

package main;

use JSON;
use DateTime;

my $zips = 'Zips';
   $zips->config->set_database('mongodbi_zips');
   
my $coll = $zips->collection; # mongodb::collection
my $data = [];

{

    local $/; #enable slurp
    open( my $fh, '<', $FindBin::Bin . '/assets/zips.json' );
    
    my $json = <$fh>;
    
    $data = decode_json($json);
    
}

ok $coll->batch_insert($data), 'batch import of data successful';

# play with model a bit

my $locale = $zips->first;

ok 'Zips' eq ref $locale, 'first locale found';
ok $locale->state() =~ /^[A-Z]{2}$/, 'locale state set ok';
ok $locale->city() =~ /^[A-Z]+$/, 'locale city set ok';
ok 'HASH' eq ref $locale->loc(), 'locale locaction set ok';
ok $locale->pop() =~ /^\d+$/, 'locale population set ok';

# let the chaining/searching begin ...

my $search = $zips->search('in_tristate_area')->query;
   
ok $search->count > 1, 'found cities in the tri-state area';

# destroy, kill, end of days

ok $zips->connection->get_database('mongodbi_zips')->drop,

    'droping database mongodbi_zips' ;