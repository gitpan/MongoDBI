package CDDB::Album;

use MongoDBI::Document;

# collection name
store 'albums';

# required fields
key 'title',    is_str,  is_req;
key 'released', is_date, is_req;

# optional fields
key 'rating', is_int, default => 1;

# embedded documents
embed 'tracks', class => 'CDDB::Track', type => 'multiple';

# related artist document
has_one 'band', class => 'CDDB::Artist';

1;
