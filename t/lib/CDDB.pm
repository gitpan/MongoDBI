package CDDB;

use MongoDBI::Application;

app {

    # shared mongodb connection
    database => {
        name => 'mongodbi_cddb',
        host => 'mongodb://localhost:27017'
    },

    # load child doc classes
    classes => {
        self => 1    # loads CDDB::*
      }

};

1;
