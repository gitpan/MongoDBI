package CDDB::Artist;

use MongoDBI::Document;

extends 'CDDB::Person';

# collection name
store 'artists';

# required fields
key 'handle', is_str;

1;
