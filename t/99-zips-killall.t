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

package main;

use JSON;
use DateTime;

my $zips = 'Zips';
   $zips->config->set_database('mongodbi_zips');
   
# destroy, kill, end of days
   
ok $zips->connection->get_database('mongodbi_zips')->drop,

    'droping database mongodbi_zips' ;