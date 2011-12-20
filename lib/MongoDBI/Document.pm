# ABSTRACT: Defines and Represents a MongoDB Collection and Document

use strict;
use warnings;

package MongoDBI::Document;
{
  $MongoDBI::Document::VERSION = '0.0.4';
}

use 5.001000;

our $VERSION = '0.0.4'; # VERSION

use Moose ('extends');

extends 'MongoDBI::Document::Base';










1;
__END__
=pod

=head1 NAME

MongoDBI::Document - Defines and Represents a MongoDB Collection and Document

=head1 VERSION

version 0.0.4

=head1 SYNOPSIS

    package CDDB::Album;

    use MongoDBI::Document;
    
    store 'albums';
    
    key 'title',    is_str,  is_req;
    key 'released', is_date, is_req;
    
    key 'rating', is_int, default => 1;
    
    has 'runtime', is_any; # will not be saved to the db
    
    embed 'tracks', class => 'CDDB::Track', type => 'multiple';
    
    has_one 'band', class => 'CDDB::Artist';
    
    1;

=head1 DESCRIPTION

MongoDBI::Document is thee class used to model objects that will be persisted in
the MongoDB database. The representation of a Document in MongoDB is a BSON
object that is very similar to a Perl hash or JSON object. Documents can be
stored in their own collections in the database, or can be embedded in other
Documents -n- levels deep.

There is one important (and probably noticeable) difference in how MongoDBI
approaches document modeling, as opposed to other MongoDB frameworks, which is
that a document class (a class that is modeled using MongoDBI::Document) has
the same specifications whether its an embedded document, relational document or
a standard document.

This is because MongoDB doesn't make that distinction so I don't see why we
should be forced to. Instead, a document is a document with the only difference
being how it is implemented ... also meaning that a single document class can
be used in different contexts (relational document, embedded document, etc).

MongoDBI::Document subclasses L<MongoDBI::Document::Base>, see that class also
for additional information.

=head2 CONVENTIONS

It is important to take a moment to familiarize yourself with the conventions
MongoDBI::Document uses, understanding these conventions will help you get
up-to-speed faster and allow you to wield all available functionality.

A MongoDBI::Document has dual roles, the class role in which the class
represents a MongoDB collection, and an object role in which the object
represents a MongoDB document, as such there are methods that can be used on
the the class (e.g. search, create, find_or_create, etc) and methods that can
be used on the object (class instance) (e.g. save, update, remove, etc).

MongoDBI::Document is NOT a wrapper around L<MongoDB::Collection>, although
there are some methods with the same name their operations are different.

The vast majority of MongoDBI::Document method take hash key/value pairs as
opposed to hash-references, ... this convention can be a gotcha for some
developers so do remember.

Naming conventions are very important in a MongoDB database and MongoDBI
document class. The following is merely an aid towards helping you name or
databases, collections, fields and indexes properly.

Databases should not be named "admin, local, or test". Collections and/or
MongoDBI document class names should not be named "system".

More importantly, Fields should never be named using terms that may collide or
overwrite the functionality of existing Moose or MongoDBI reserved words or
methods. Those terms include but are not limited to the following:

    package EggNoodle;
    
    use MongoDBI::Document ; # +Moose
    
    key 'has' ;     # BAD
    key 'can' ;     # BAD
    key 'extends' ; # BAD
    
    # ... and other Moose keywords
    
    key 'id' ;      # BAD
    key 'name' ;    # BAD
    key 'key' ;     # BAD
    key 'store' ;   # BAD
    key 'change' ;  # BAD
    key 'config' ;  # BAD
    key 'file' ;    # BAD
    
    # ... and other MongoDBI::Document::Sugar keywords
    
    index 'name' ;      # BAD
    index 'unique' ;    # BAD
    index 'drop_dups' ; # BAD
    index 'safe' ;      # BAD
    index 'background' ;# BAD
    
    # ... and other MongoDB indexing option keys
    
    1;

For now it is important for you to avoid using these names and others that
might collide with some inherited functionality. As a rule, simply name things
as specifically as possible. I apologize for any inconvenience. Please
familiarize yourself with L<Moose>'s keywords as well as the keywords found in
L<MongoDBI::Document::Sugar>.

=head2 CONFIGURATION

Each MongoDBI::Document can have a completely different configuration including
its database and host. It is not only possible, but easy as well, to have
different classes operating on different machines.

    package CDDB::Album;
    use MongoDBI::Document;
    
    package main;
    
    my $config = CDDB::Album->config;
    $config->set_database(name => 'cddb');

=head2 DOCUMENT STORAGE

MongoDBI::Document by default generates its collection name by transforming the
class name and pluralizing it thus storing the class Album in the collection
albums, or CDDB::Album in the collection cddb_albums. This functionality can be
averted by using the store() declaration or using the set_collection() config
method. Read more on these methods in L<MongoDBI::Document::Config>.

    # option A
    package CDDB::Album;
    use MongoDBI::Document;
    
    store 'my_albums'; # collection name literally
    
    # option B
    package CDDB::Album;
    use MongoDBI::Document;
    
    package main;
    CDDB::Album->config->set_collection(name => 'the_albums');
    
    # option C
    CDDB::Album->config->set_collection(
        naming => ['short', 'plural']
    );
    
    # valid option C naming keys are as follows:
    
        * same - as-is
        * short - only the final portion of the package name
        * plural - unintelligent 's' adder
        * decamel - MyApp becomes my_app
        * undercolon - :: becomes _
        * lower/lc - lowercase string
        * upper/uc - uppercase string
        * default - same as (decamel, undercolon, lower, plural)

=head2 FIELD DECLARATIONS

MongoDBI::Document exports L<Moose> making your class a Moose class (technically)
which means that Moose-base class declarations and rules apply however it is
important to note that MongoDBI::Document exports its own sugary goodness for
defining document classes, more-to-the-point, Moose attributes declared with
the has() declaration will be ignored by MongoDBI::Document mechanisms. For more
information on said sugary goodness, please review L<MongoDBI::Document::Sugar>.

This blatant disregard is a feature, and allows us to have "protected" document
class fields that are used (e.g. by user-defined methods, etc) within our
application but never saved to the database.

When a class attribute needs to be declared as a database document key, the
key() declaration should be used. The key() declaration can be passed any
arguments which can be legally passed to Moose's has() method. Additionally,
L<MongoDBI::Document::Sugar> exports a few relevant attribute argument
shorthands for your convenience such as (is_str, is_int, is_date, etc.).

Consider the follow simple class for modeling an album:

    package CDDB::Album;

    use MongoDBI::Document;
    
    key 'title',    is_str,  is_req;
    key 'released', is_date, is_req;
    key 'rating',   is_int,  default => 1;
    
    has 'active',   is_str; # never saved to the db
    
    # is_str  == (is => 'rw', isa => 'Str')
    # is_int  == (is => 'rw', isa => 'Int')
    # is_date == (is => 'rw', isa => 'DateTime')
    
    # etc.
    
    1;

If you do not specify the type of field with the declaration, MongoDBI::Document
will treat it as a String as that is the most commonly used field type.

Once instantiated, you can/will update the object attributes in the same way as
you would using a traditional Moose class.

PLEASE NOTE! There currently is NO mechanism in place to die or warn you if you
define a field on your document that conflicts with a reserved word, attribute
of method within the MongoDBI core, ... so please use caution and common sense
naming. Although it may be pretty tempting to create a field on your class
named 'name' but I would advise against it, .. instead try fullname or similar.

For a complete list of keywords and declarations, please see the
L<MongoDBI::Document::Sugar> documentation.

=head2 FIELD DIRTY TRACKING

MongoDBI::Document supports the tracking of changed or "dirty" fields by placing
triggers on class attributes which retain a complete history of the changes to
its field for the life of the parent object.

If a defined field has been modified by it will be marked as dirty and
accessible as follows:

    use CDDB::Album;
    
    my $cd = CDDB::Album->new(title => 'LifeTime', released => DateTime->now);
    
    if ($cd->changed) {
        
        # okay, what changed?
        if ($cd->changed('title')) {
            
            print "You changed the title!";
            print "Title is now, ", $cd->change('title')->{new_value};
            
        }
        
    }
    
    # or, ... directly access the history
    $cd->_dirty->{title}->[2]->{new_value}; # 3rd title change
    $cd->_dirty->{title}->[2]->{old_value}; # value before 3rd title change

=head2 CLASS INHERITANCE

MongoDBI::Document, being a Moose class itself, supports inheritance much in
the exact same way as Moose in both root and embedded documents. In scenarios
where document classes are inherited from other document classes, their fields,
indexes, declarations, etc, get copied up the chain into derived class.

    {
        package CDDB::Person;
        
        use MongoDBI::Document;
        
        key 'fullname', is_str, is_req, is_unique;
    }
    
    {
        package CDDB::Artist;
        
        use MongoDBI::Document;
        
        extends 'CDDB::Person';
        
        store 'artists';
        
        key 'handle', is_str;
    }

=head2 STANDARD OPERATIONS, QUERYING, ETC

MongoDBI::Document leverages the role L<MongoDBI::Document::Storage::Operation>
to provide a standard range of common methods you would expect to find in any
other ORM, ODM, database framework.

    * CDDB::Album->count
    * CDDB::Album->create(...)
    * CDDB::Album->find(...)
    * CDDB::Album->find_one(...)
    * CDDB::Album->find_or_create(...)
    * CDDB::Album->find_or_new(...)
    * CDDB::Album->first
    * CDDB::Album->last
    * CDDB::Album->new(...)->save
    * CDDB::Album->create(...)->remove
    * CDDB::Album->create(...)->update
    * CDDB::Album->search
    
    ... etc

One of MongoDBI's greatest features is its querying abstraction layer handled by
L<MongoDBI::Document::Storage::Criterion>, please review that documentation for
an in-depth look at MongoDBI's querying facilities. Most all queries in MongoDBI
are wrapped around a L<MongoDBI::Document::Storage::Criterion> object, which is
a chainable object for building complex and dynamic queries. The querying
object will never hit the database until you tell it to.

The following is an example of how MongoDBI's querying abstraction facilities
can be used:

    * CDDB::Album->search->all_in(...)
    * CDDB::Album->search->all_of(...)
    * CDDB::Album->search->also_in(...)
    * CDDB::Album->search->any_in(...)
    * CDDB::Album->search->any_of(...)
    * CDDB::Album->search->asc_sort(...)
    * CDDB::Album->search->desc_sort(...)
    * CDDB::Album->search->select(...)
    
    ... etc
    
    my $search = CDDB::Album->search;
       $search = $search->where('released$lt' => DateTime->now->set(...));
       $search = $search->asc_sort('title')->limit(25);
       
    my $mongodb_cursor = $search->query;

While we're on the topic of serious querying, MongoDBI::Document also allows you
to define "chains" on your classes as a convenience for generating complex
query strings. Chains (chainable search objects) are declared on
MongoDBI::Document classes using the chain() declaration. All class chains are
chainable and might look as follows:

    package CDDB::Artist;
    
    use MongoDBI::Document;
    
    extends 'CDDB::Person';
    
    store 'artists';
    
    key 'handle', is_str;
    
    chain 'is_legal' => sub { shift->and_where('age$gt' => 21) }
    chain 'is_local' => sub { shift->and_where('state$in' => ['PA', 'NJ']) }
    
    package main;
    
    my $artists = CDDB::Artist;
    
    my $mongodb_cursor = $artists->is_legal->is_local->query; 

=head2 DOCUMENT CLASS RELATIONSHIPS

As previously stated, with MongoDBI::Document classes, the only difference
between embedded, relational and standard documents are how they're declared to
be applied to the database. All types of documents are designed as
MongoDBI::Document classes. Declaring a document class to be applied to the
database as an embedded or relational document simply means declaring a
relationship between two document classes. The declarations used to declare such
relationships are embed(), has_one(), and has_many(). These declarations are
exported by and explained in further detail in the L<MongoDBI::Document::Sugar>
documentation.

Document class relationships are associations between one document and another.
The embedded document relationship describes a child document(s) stored within a
parent document. The relational (referenced) document relationship describes
a document(s) referenced by separate document in separate collection.

MongoDBI::Document classes declared to be related to other document classes are
wrapped by object-based proxies for the actual document class which provides
functionality for accessing, replacing, appending and persisting.

Consider the following example which declares both an embedded and relational
relationship:

    package CDDB::Album;

    use MongoDBI::Document;
    
    ...
    
    embed 'producer', class => 'CDDB::Person';
    embed 'tracks', class => 'CDDB::Track', type => 'multiple';
    
    has_one 'band', class => 'CDDB::Artist';
    has_many 'compilations', class => 'CDDB::Album';
    
    package main;
    
    my $albums = CDDB::Album;
    my $album  = $albums->new(...);
    
    $album->producer->add(name => 'Mike Nice');
    $album->tracks->add(title => 'Rainbow Bum');
    $album->tracks->add(title => 'Silver Gazelle');
    
    $album->band->add(name => 'Randy Watson', handle => 'Sexual Chocolate');
    
    $album->save;

For a more in-depth look at relationships, please review the documentation for
L<MongoDBI::Document::Child> and L<MongoDBI::Document::Relative>.

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

