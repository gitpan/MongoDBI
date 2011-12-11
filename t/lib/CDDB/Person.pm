package CDDB::Person;

use MongoDBI::Document;

# collection name
# (although it will be used as a base class and not stored seperately)
store 'people';

# required fields
key 'fullname', is_str, is_req, is_unique;

1;
