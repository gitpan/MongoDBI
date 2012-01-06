package CDDB::Track;

use MongoDBI::Document;

# collection name
# (although it will be used as an embedded doc and not stored seperately)
store 'tracks';

# required fields
key 'title', is_str, is_req;

file 'mp3';

# related artist documents
has_many 'artists', class => 'CDDB::Artist';

1;
