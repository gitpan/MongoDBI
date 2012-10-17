package CDDB::Node;

use MongoDBI::Document;
use MongoDB;
use MongoDB::OID;
use DateTime;

store 'nodes';

key '_id', is_id, is_req default => sub { MongoDB::OID->new };

key 'owner', is_id, is_req;

key 'created', is_date default => sub { DateTime->now }, is => 'ro', is_req;
key 'updated', is_date default => sub { DateTime->now }, is_req;

key 'content', is_str, is_req;

embed 'children', class => __PACKAGE__, type => 'multiple';
