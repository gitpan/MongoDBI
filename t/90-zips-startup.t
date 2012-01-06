use Test::More;

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib $FindBin::Bin . '/lib';
    use lib $FindBin::Bin . '/../lib';

    plan $ENV{TEST_MONGODBI}
      ? ( tests => 1 )
      : ( skip_all => 'TEST_MONGODBI is not set. Tests skipped.' );
}

package Zips;

use MongoDBI::Document;

store 'zips';

index 'loc', '2d'; # geospatial index

package main;

use JSON;

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
