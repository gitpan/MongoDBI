# ABSTRACT: Standard MongoDBI Document/Collection Operations

use strict;
use warnings;

package MongoDBI::Document::Storage::Operation;
{
  $MongoDBI::Document::Storage::Operation::VERSION = '0.0.10';
}

use 5.001000;

our $VERSION = '0.0.10'; # VERSION

use Moose::Role;

use MongoDB::OID;
use MongoDBI::Document::Storage::Criterion;
use MongoDBI::Document::Child;
use MongoDBI::Document::Relative;
use MongoDBI::Document::GridFile;



sub all {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ?
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) if values %where;
       
    return $search->query->all;
    
}


sub clone {
    
    my ($self) = @_;
    
    $self->is_instance('clone');
    
    die "clone can only be performed on an instance " .
        "with an ID" unless $self->id;
    
    my $attributes = $self->collapse;
    
    delete $attributes->{_id};
    
    my $class = ref $self;
    my $clone = $class->new(%{$attributes});
    
    return $clone;
    
}

sub collapse {

    my $self = shift;
    my $data = {};
    
    # in an attempt to achieve maximum efficiency, only collapse dirty fields
    while (my($field, $changes) = each(%{$self->_dirty})) {
        
        $data->{$field} = $changes->[-1]->{new_value};
        
    }
    
    # collapse related doc classes
    while (my($name, $config) = each(%{$self->config->fields})) {
        
        # collapse embedded gridfs documents
        if ($config->{isa} eq 'MongoDBI::Document::GridFile') {
            
            if ($config->{type} eq 'single') {
                
                my $grids  = $self->$name->target;
                my $object = $self->$name->object;
                
                if ($object) {
                    
                    $data->{$name} = $object;
                    
                }
                
            }
            
            if ($config->{type} eq 'multiple') {
                
                if ("ARRAY" eq ref $self->$name->object) {
                    
                    my $grids  = $self->$name->target;
                    
                    foreach my $object (@{$self->$name->object}) {
                        
                        push @{$data->{$name}}, $object;
                        
                    }
                    
                }
                
            }
            
        }
        
        # collapse embedded documents
        elsif ($config->{isa} eq 'MongoDBI::Document::Child') {
            
            if ($config->{type} eq 'single') {
                
                my $embedded = $self->$name->object->collapse;
                $data->{$name} = $embedded if $embedded;
                
            }
            
            if ($config->{type} eq 'multiple') {
                
                if ("ARRAY" eq ref $self->$name->object) {
                    
                    foreach my $object (@{$self->$name->object}) {
                        
                        my $embedded = $object->collapse;
                        push @{$data->{$name}}, $embedded if $embedded;
                        
                    }
                    
                }
                
            }
            
        }
        
        # collapse related documents
        elsif ($config->{isa} eq 'MongoDBI::Document::Relative') {
            
            if ($config->{type} eq 'single') {
                
                my $class  = $self->$name->target;
                my $object = $self->$name->object;
                
                if ($object) {
                    
                    $data->{$name} = {
                        '$id'  => $object,
                        '$ref' => $class->config->collection->{name}
                    };
                    
                }
                
            }
            
            if ($config->{type} eq 'multiple') {
                
                if ("ARRAY" eq ref $self->$name->object) {
                    
                    my $class  = $self->$name->target;
                    
                    foreach my $object (@{$self->$name->object}) {
                        
                        push @{$data->{$name}}, {
                            '$id'  => $object,
                            '$ref' => $class->config->collection->{name}
                        };
                        
                    }
                    
                }
                
            }
            
        }
        
        # additionally, be mindful of fields with default values
        # if they had been set by the app, they'd be marked as dirty and
        # should exist in $data ... if they haven't been set but have default
        # values, try the accessor
        if (! defined $data->{$name} && $config->{default}) {
            
            $data->{$name} = "CODE" eq ref $config->{default} ?
                $config->{default}->($self) : $config->{default};
            
        }
        
    }
    
    # add id if applicable
    $data->{'_id'} = $self->_id if $self->id;
    
    return $data;

}


sub collection {
    
    my $class = shift;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    return $class->config->_mongo_collection;
    
}


sub connection {
    
    my $class = shift;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    return $class->config->_mongo_connection;
    
}


sub count {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ?
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) if values %where;
       
    return $search->query->count;
    
}


sub create {
    
    my ($class, %args) = @_;
    
    $class = ref $class if ref $class ;
    
    my $new = $class->new(%args);
    
    $new->insert;
    
    return $new;
    
}


sub execute_on {
    
    my $self = shift;
    my $code = pop;
    
    my %args = ();
    
    my $db   = $self->config->database;
    
    if (@_ == 1 && lc($_[0]) eq 'slave' || lc($_[0]) eq 'master') {
        
        if (lc($_[0]) eq 'master') {
        
            %args = $db->{master} ?
                %{$db->{master}} : %{$db} ;
            
        }
        
        if (lc($_[0]) eq 'slave') {
            
            %args = $db->{slaves} ?
                @{$db->{slaves}}[rand(@{$db->{slaves}})] : %{$db} ;
            
        }
        
    }
    else {
        
        %args = @_ >= 1 ? (host => $_[0]) : @_;
        
    }
    
    die "execute_on requires a FQDN or Server IP address to connect to"
        unless $args{host};
        
    die "execute_on requires a CODEREF to be executed against the target server"
        unless "CODE" eq ref $code;
    
    return $code->($self) # return immediately
        if lc($args{host}) eq 'localhost' || $args{host} eq '127.0.0.1';
    
    my $orig_host = $self->config->database;
    
    $self->config->set_database(%args);
    $self->config->database->{connected} = 0; 
    
    my $result = $code->($self);
    
    $self->config->set_database(%{$orig_host});
    $self->config->database->{connected} = 0; # connect
    
    return $result;
    
}

sub expand {
    
    my ($class, %data) = @_;
    
    $class = ref $class || $class; # ensure class-hood
    
    my %args = (); # expanded attribute data
    
    # ...
    my $config  = $class->config;
    my $db_name = $config->database->{name};
    my $conn    = $config->_mongo_connection;
    
    # fetch the gridfs object, it may be needed
    my $grid_fs = $conn->get_database($db_name)->get_gridfs;
    
    # expand $data into class attributes
    while (my($name, $config) = each(%{$class->config->fields})) {
        
        if ($config->{isa} eq 'MongoDBI::Document::GridFile') {
            
            if ($config->{type} eq 'single') {
                
                my %gridfile_args = %{$config};
                my $gridfile = MongoDBI::Document::GridFile->new(
                    parent => $class,
                    target => $grid_fs,
                    config => { %gridfile_args },
                );
                
                $gridfile->object($data{$name});
                
                $args{$name} = $gridfile;
                
            }
            
            elsif ($config->{type} eq 'multiple') {
                
                if ("ARRAY" eq ref $data{$name}) {
                    
                    my %gridfile_args = %{$config}; delete $gridfile_args{class};
                    my $gridfile = MongoDBI::Document::GridFile->new(
                        parent => $class,
                        target => $grid_fs,
                        config => { %gridfile_args },
                    );
                    
                    $gridfile->object([])
                        unless "ARRAY" eq ref $gridfile->object;
                    
                    foreach my $doc (@{$data{$name}}) {
                        
                        push @{$gridfile->object}, $doc;
                        
                    }
                    
                    $args{$name} = $gridfile;
                    
                }
                
            }
            
        }
        
        elsif ($config->{isa} eq 'MongoDBI::Document::Child') {
            
            if ($config->{type} eq 'single') {
                
                my %child_args = %{$config}; delete $child_args{class};
                my $child = MongoDBI::Document::Child->new(
                    parent => $class,
                    target => $config->{class},
                    config => { %child_args },
                );
                
                # children can have children
                my @good_data = $config->{class}->expand(%{$data{$name}});
                
                $child->add(@good_data);
                
                $args{$name} = $child;
                
            }
            
            elsif ($config->{type} eq 'multiple') {
                
                if ("ARRAY" eq ref $data{$name}) {
                    
                    my %child_args = %{$config}; delete $child_args{class};
                    my $child = MongoDBI::Document::Child->new(
                        parent => $class,
                        target => $config->{class},
                        config => { %child_args },
                    );
                    
                    foreach my $doc (@{$data{$name}}) {
                        
                        # children can have children, yeah
                        my @good_data = $config->{class}->expand(%{$doc});
                        
                        $child->add(@good_data);
                        
                    }
                    
                    $args{$name} = $child;
                    
                }
                
            }
            
        }
        
        elsif ($config->{isa} eq 'MongoDBI::Document::Relative') {
            
            if ($config->{type} eq 'single') {
                
                my %relative_args = %{$config};
                my $relative = MongoDBI::Document::Relative->new(
                    parent => $class,
                    target => $config->{class},
                    config => { %relative_args },
                );
                
                $relative->object($data{$name}->{'$id'});
                
                $args{$name} = $relative;
                
            }
            
            elsif ($config->{type} eq 'multiple') {
                
                if ("ARRAY" eq ref $data{$name}) {
                    
                    my %relative_args = %{$config}; delete $relative_args{class};
                    my $relative = MongoDBI::Document::Relative->new(
                        parent => $class,
                        target => $config->{class},
                        config => { %relative_args },
                    );
                    
                    $relative->object([])
                        unless "ARRAY" eq ref $relative->object;
                    
                    foreach my $doc (@{$data{$name}}) {
                        
                        push @{$relative->object}, $doc->{'$id'};
                        
                    }
                    
                    $args{$name} = $relative;
                    
                }
                
            }
            
        }
        
        else {
            
            $args{$name} = $data{$name} if defined $data{$name};
            
        }
        
    }
    
    # add id if applicable
    if ( $data{_id} ) {
        
        if ( ref $data{_id} ) {
            $args{_id} = $data{_id};
        }
        else {
            $args{_id} = MongoDB::OID->new( value => $data{'_id'} );
        }
        
    }
    
    return %args;
    
}


sub find {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ? 
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) if values %where;
       
    return $search->query;
    
}


sub find_one {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ? 
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) if values %where;
       $search->limit(-1);
    
    my $data = $search->query->next;
    
    return $data ? $class->new($class->expand(%{$data})) : undef;
    
}


sub find_or_create {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ? 
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $instance = $class->find_one(%where);
    
    return $instance ? $instance : $class->create(%where) ;
    
}


sub find_or_new {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ? 
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $instance = $class->find_one(%where);
    
    return $instance ? $instance : $class->new($class->expand(%where)) ;
    
}


sub full_name {
    
    my $self = shift;
    
    $self->connect unless $self->config->database->{connected};
    
    my $collection = $self->_mongo_collection;
    my $connection = $self->_mongo_connection;
    
    return join ".", $connection->db_name, $collection->name;
    
}


sub first {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ? 
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) if values %where;
       $search->limit(-1);
       $search->asc_sort('_id');
    
    my $data = $search->query->next;
    
    return $data ? $class->new($class->expand(%{$data})) : undef;
    
}


sub insert {
    
    my ($self) = @_;
    
    $self->is_instance('insert');
    
    die "insert cannot be performed on an instance " .
        "with an ID (" . $self->id . ")" if $self->id;
    
    $self->connect unless $self->config->database->{connected};
    
    my $collection = $self->config->_mongo_collection;
    
    $self->_id($collection->insert($self->collapse, $self->config->options));
    
    return $self;
    
}

sub is_instance {
    
    my ($self, $op) = @_;
    
    $op ||= "this operation";
    
    die $op . " can only be performed on an instance, " .
        "try using " . ($self||'Class') . "->new(...);"
        
        unless ref $self ;
        
    return $self ;
    
}


sub last {
    
    my ($class, @where) = @_;
    
    my %where = @where == 1 ? 
        (_id => MongoDB::OID->new(value => $where[0])) : @where ;
    
    $class = ref $class if ref $class ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) if values %where;
       $search->limit(-1);
       $search->desc_sort('_id');
    
    my $data = $search->query->next;
    
    return $data ? $class->new($class->expand(%{$data})) : undef;
    
}


sub name {
    
    my $self = shift;
    
    $self->connect unless $self->config->database->{connected};
    
    return $self->config->_mongo_collection->name;
    
}


sub query {
    
    my ($self, @filters) = @_;
    
    my $config = $self->config;
    
    confess("config attribute not present") unless blessed($config);

    return $self->search(@filters)->query;
    
}


sub reload {
    
    my ($self) = @_;
    
    $self->is_instance('reload');
    
    die "reload can only be performed on an instance " .
        "with an ID" unless $self->id;
    
    my %where = (_id => $self->_id) ;
    
    my $class = ref $self ;
    
    $class->connect unless $class->config->database->{connected};
    
    my $search = $class->search;
       $search->where(%where) ;
       $search->limit(-1);
    
    my $data = $search->query->next;
    
    return $data ? $class->new($class->expand(%{$data})) : undef;
    
}


sub remove {
    
    my ($self) = @_;
    
    $self->is_instance('remove');
    
    die "remove can only be performed on an instance " .
        "with an ID" unless $self->id;
    
    $self->connect unless $self->config->database->{connected};
    
    my $collection = $self->config->_mongo_collection;
    
    $collection->remove({ _id => $self->_id }, $self->config->options) ;
    
    # no longer assoc to a record
    $self->_id->{value} = 0;
    
    # leaving dirty tracking in-tact
    
    return $self;
    
}


sub save {
    
    my ($self) = @_;
    
    $self->is_instance('save');
    
    die "save cannot be performed on an instance " .
        "without an ID" unless $self->id;
        
    die "save cannot be performed on an instance " .
        "without any altered keys" unless values %{$self->_dirty};
    
    $self->connect unless $self->config->database->{connected};
    
    my $collection = $self->config->_mongo_collection;
    
    $collection->save($self->collapse, $self->config->options);
    
    return $self;
    
}


sub search {
    
    my ($self, @searches) = @_;
    
    my $config = $self->config;
    
    confess("config attribute not present") unless blessed($config);

    $self->connect unless $config->database->{connected};
    
    my $criteria = MongoDBI::Document::Storage::Criterion->new(
        collection => $config->_mongo_collection
    );
    
    if (@searches) {
        
        while (my $key = shift @searches) {
            
            my @args = ();
            
            while (@searches && !$config->searches->{$searches[0]}) {
                
                push @args, shift @searches;
                
            }
            
            my $search = $config->searches->{$key};
            
            $criteria = $search->($criteria, $self, @args);
            
        }
        
    }
    
    return $criteria;
    
}


sub update {
    
    my ($self, %options) = @_;
    
    $self->is_instance('update');
    
    die "update cannot be performed on an instance " .
        "without an ID" unless $self->id;
        
    die "update cannot be performed on an instance " .
        "without any altered keys" unless values %{$self->_dirty};
    
    $self->connect unless $self->config->database->{connected};
    
    my $collection = $self->config->_mongo_collection;
    
    my $change = delete $options{set}; # should the doc be appended or replaced
       
       $change ||= 1; # yes, by default
    
    $options{upsert}   ||= 0;
    $options{multiple} ||= 1;
    
    my $data = $change ? $self->collapse : { '$set' => $self->collapse };
    
    $collection->update({ _id => $self->_id }, $data, $self->config->options);
    
    return $self;
    
}

no Moose::Role;

1;
__END__
=pod

=head1 NAME

MongoDBI::Document::Storage::Operation - Standard MongoDBI Document/Collection Operations

=head1 VERSION

version 0.0.10

=head1 SYNOPSIS

    package main;

    my $cds = CDDB::Album;
    
    my @cds = $cds->all; # returns all records (as hashes not instances)
    
    foreach my $cd (@cds) {
        
        my $this_cd = $cds->new(%{ $cd });
        my $that_cd = $this_cd->clone;
        
        $this_cd->rating(5);
        $that_cd->rating(1);
        
        $this_cd->save; # save changes to existing cd
        $that_cd->insert; # new cd record
        
    }
    
    1;

=head1 DESCRIPTION

MongoDBI::Document::Storage::Operation is a role that provides
collection-specific functionality to your MongoDBI document classes.

=head1 METHODS

=head2 all

The all method, called on the class or instance, returns an arrayref of
hashrefs corresponding to the documents in the document class collection which
match the criteria specified.

    my @cds = CDDB::Album->all;
    
    ... db.albums.find();
    
    my @cds = CDDB::Album->all(title => 'Thriller');
    
    ... db.albums.find({ "title" : "thriller" });
    
    # using M::D::S::Criterion query syntax
    my @cds = CDDB::Album->all('rating$gt' => 10); 
    
    ... db.albums.find({ "rating" : { "$gt" : 10 } });

=head2 clone

The clone method, can only be called on a class instance which has been
previously inserted thus having a valid ID, returns a cloned instance of itself
including set attributes and configuration minus its ID.

    my $cd1 = CDDB::Album->first; # get the first record as an instance
    
    my $cd2 = $cd1->clone;
    
    $cd2->insert; # insert not save, can't save without an id

=head2 collection

The collection method, called on a class or instance, simply returns the
L<MongoDB::Collection> object set in the current document class configuration.

    my $mongo_col = CDDB::Album->collection;

=head2 connection

The connection method, called on a class or instance, simply returns the
L<MongoDB::Connection> object set in the current document class configuration.

    my $mongo_con = CDDB::Album->connection;

=head2 count

The count method, called on a class or instance, simply returns the total number
of documents matching the specified criteria.

    my $count = CDDB::Album->count;
    
    ... db.albums.find().count();
    
    my $count = CDDB::Album->all(title => 'Thriller');
    
    ... db.albums.find({ "title" : "thriller" }).count();

=head2 create

The create method, called on a class or instance, inserts a new document into
the database and returns the newly create class instance.

    my $cd = CDDB::Album->create(title => 'Greatest HITS', released => ...);
    
    $cd->title('Greatest Hits');
    
    $cd->save;

=head2 execute_on

The execute_on method, called on a class or instance, is designed to allow
the execution of specific database commands against alternate database servers.
While it was certainly the goal for this method to be instrumental in providing
support for MongoDB clustered environments (master/slave, replicasets, etc),
this method has many applications.

    my $cds = CDDB::Album;
    
    my @cds = $cds->all; # returns all records (from 127.0.0.1, default)
    
    $cds->execute_on('192.168.1.101' => sub {
    
        foreach my $cd (@cds) {
            
            # save changes to cd on the master server
            $cd->rating(5);
            $cd->save; 
            
        }
    
    });
    
    # or ...
    
    $cds->execute_on(name => 'alt_dbname', host => '192.168.1.101', sub {
    
        foreach my $cd (@cds) {
            
            # save changes to cd on the master server
            $cd->rating(5);
            $cd->save; 
            
        }
    
    });
    
    # or ...
    # if using MongoDBI::Application with connection pooling
    
    my @cds = $cds->execute_on('slave' => sub {
    
        return shift->all
    
    });
    
    $cds->execute_on('master' => sub {
    
        foreach my $cd (@cds) {
            
            # save changes to cd on the master server
            $cd->rating(5);
            $cd->save; 
            
        }
    
    });

=head2 find

The find method, called on a class or instance, not to be confused with the find
method available via the L<MongoDB> driver, allows you to quickly query a
resultset using the syntax described in L<MongoDBI::Document::Storage::Criterion>.

The find method always returns a L<MongoDB::Cursor> object, it accepts a single
argument (just the document ID, not MongoDB::OID) or key/value query syntax. If
you would like to pass in a MongoDB::OID object to reference the document ID,
please use the following syntax:

    my $cd = CDDB::Album->find('4df7a599005ec15814000000')->next;
    
    my $cd = CDDB::Album->find(_id => $mongo_oid)->next;
    
    my $search = CDDB::Album->find(title => qr/Hits/);
    
    while (my $cd = $search->next) {
        
        ...
        
    }

=head2 find_one

The find_one method, called on a class or instance, not to be confused with the
find_one method available via the L<MongoDB> driver, allows you to quickly query
a resultset using the L<MongoDBI::Document::Storage::Criterion> syntax.

The find_one method tries to return an instance of the current class based on
the result of the query. The find_one method accepts a single argument
(just the document ID, not MongoDB::OID) or key/value query syntax. If
you would like to pass in a MongoDB::OID object to reference the document ID,
please use the following syntax:

    my $cd = CDDB::Album->find_one('4df7a599005ec15814000000');
    
    my $cd = CDDB::Album->find_one(_id => $mongo_oid);
    
    my $search = CDDB::Album->find_one(title => qr/Hits/);

=head2 find_or_create

The find_or_create method, called on a class or instance, attempts to find a
single document based on the passed-in criteria, returning a class instance
based on the returned document, if no matching documents can be found inserts a
new document into the database and returns the newly create class instance.

    my $cd = CDDB::Album->find_or_create(title => 'Greatest HITS');
    
    $cd->save;

=head2 find_or_new

The find_or_new method, called on a class or instance, attempts to find a
single document based on the passed-in criteria, returning a class instance based
on the returned document, if no matching documents can be found instantiates and
returns a new class object.

    my $cd = CDDB::Album->find_or_new(title => 'Greatest HITS');
    
    $cd->id ? $cd->save : $cd->insert;

=head2 full_name

The full_name method, called on a class or instance, simply returns the
fully-qualified database collection name based on the collection and
connection configuration.

    CDDB::Album->config->set_database('test');
    
    my $col_name = CDDB::Album->full_name;
    
    print $col_name; # prints test.albums

=head2 first

The first method, called on a class or instance, allows you to quickly query
a resultset using the L<MongoDBI::Document::Storage::Criterion> syntax returning
an instance of the current class based on the first result of the query
automatically sorted by ID in ascending order. The first method accepts key/value
query syntax.

    my $cd = CDDB::Album->first; 
    
    my $cd = CDDB::Album->first(title => qr/Hits/);

=head2 insert

The insert method, can only be called on a class instance which has NOT been
previously inserted thus not having an ID set, collapses the dirty
attributes/fields and inserts the instance into the defined collection returning
itself.

    my $cd1 = CDDB::Album->new(...); 
    
    $cd1->insert;

=head2 last

The last method, called on a class or instance, allows you to quickly query
a resultset using the L<MongoDBI::Document::Storage::Criterion> syntax returning
an instance of the current class based on the last result of the query
automatically sorted by ID in descending order. The last method accepts key/value
query syntax.

    my $cd = CDDB::Album->last; 
    
    my $cd = CDDB::Album->last(title => qr/Hits/);

=head2 name

The name method, called on a class or instance, simply returns the name of
the database collection based on the collection configuration.

    my $col_name = CDDB::Album->name;
    
    print $col_name; # prints albums

=head2 query

The query method, called on a class or instance, is shorthand (an alias) for
calling the search method and eventually calling the query method within
L<MongoDBI::Document::Storage::Criterion> package executing pre-defined filters
and returning the resulting L<MongoDB::Cursor> object.

    package CDDB::Album;
    
    use MongoDBI::Document;
    
    filter 'w_quantity' => sub {
        my ($filter, $self, $cond, $value) = @_;
        $filter->and_where("quantity$cond" => $value);
    };
    
    package main;

    # note: any arg not recognized as an pre-defined filter is passed to the
    # filter preceding it
    
    my $cursor = CDDB::Album->query('w_quantity', '$gte', 1000);
    
    # is the equivalent of ...
    
    my $search = CDDB::Album->search->where('w_quantity', '$gte', 1000);
    
    my $cursor = $search->query;
    
    while (my $document = $cursor->next) {
        
        ...
        
    }

=head2 reload

The reload method, can only be called on a class instance which has been
previously inserted thus having an ID set, uses the ID to poll the database
returning a new instance object based on the query result if any.

This method is useful in stateless applications or applications where the
instance may remain in-use for an inordinate amount of time allowing someone
else the possibility to update that exact same record with information that
differs from your own unsaved object thus having your eventual save overwrite
their changes.

    my $cd1 = CDDB::Album->first;
    
    ... 10 mins later ...
    
    # i should probably reload this object before making changes
    
    $cd1->reload;
    
    $cd1->title(...); # change it
    
    $cd1->save;

=head2 remove

The remove method, can only be called on a class instance which has been
previously inserted thus having an ID set, uses the ID to poll the database
for the corresponding document and removes it (both on the object and in the
collection) returning a copy of the original before deletion.

    my $cd1 = CDDB::Album->first;
    
    # $cd1 = $cd1->remove; if you're a stickler for convention
    
    $cd1->remove;
    
    $cd1->title(...); # completely new title
    
    $cd1->insert; # new document based on the deleted

=head2 save

The save method, can only be called on a class instance which has been
previously inserted thus having an ID set, uses the ID to poll the database
for the corresponding document updating the "dirty fields only" while saving it
to the database.

    my $cd1 = CDDB::Album->first;
    
    $cd1->save; # saves nothing
    
    $cd1->title(...); # completely new title
    
    $cd1->save; # save, updating the title only, not the entire document

=head2 search

The search method, called on a class or instance, simply returns a
L<MongoDBI::Document::Storage::Criterion> object allowing you to build complex
queries.

    my $search = CDDB::Album->search;
    
    my $search = CDDB::Album->search->where('title$in' => ['Bad', 'Thriller']);
    
    # call query to return a MongoDB::Cursor object for further usage
    
    my $cursor = $search->query;
    
    while (my $document = $cursor->next) {
        
        ...
        
    }

The search method also supports another syntax for chaining stored
queries/filters.

    package CDDB::Album;
    
    use MongoDBI::Document;
    
    filter 'filter_a' => sub {
        my ($filter, $self, @
        ) = @_;
        $filter->and_where(...)
    };
    
    filter 'filter_b' => sub {
        my ($filter, $self, @args) = @_;
        $filter->and_where(...)
    };
    
    package main;

    my $search = CDDB::Album->search('filter_a', 'filter_b');
    
    # experimental syntax (pass args to filters)
    # my $search = CDDB::Album->search('filter_a', 'filter_b' => (1..9));
    # my $search = CDDB::Album->search('filter_a' => (1..9), 'filter_b');
    
    my $cursor = $search->query;
    
    while (my $document = $cursor->next) {
        
        ...
        
    }

=head2 update

The update method, unlike the L<MongoDB> driver update method, can only be called
on a class instance which has been previously inserted thus having an ID set,
uses the ID to poll the database for the corresponding document updating the
"dirty fields only" while saving it to the database. The main difference between
the update method and the save method is that the update method can change the
entire structure of the document by discarding fields that haven't been set.

You can safely use the save option where the update function might sound like
the right choice, and only use the update option when needed (knowing exactly
what it does). The following is an example:

    my $cd1 = CDDB::Album->first;
    
    $cd1->update; # updates nothing
    
    $cd1->title(...); # completely new title
    
    $cd1->update; # update, updating the title only, not the entire document
    
    $cd1->update(set => 0); # update, replacing the document with title and ID

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

