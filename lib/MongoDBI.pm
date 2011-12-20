# ABSTRACT: A proper ODM (Object-Document-Mapper) for MongoDB 

use strict;
use warnings;

package MongoDBI;
{
  $MongoDBI::VERSION = '0.0.4';
}

use 5.001000;

our $VERSION = '0.0.4'; # VERSION

use Moose ('extends');

extends 'MongoDBI::Application';


1;
__END__
=pod

=head1 NAME

MongoDBI - A proper ODM (Object-Document-Mapper) for MongoDB 

=head1 VERSION

version 0.0.4

=head1 SYNOPSIS

    package CDDB;

    use MongoDBI;
    
    app {
    
        # shared mongodb connection
        database => {
            name => 'mongodbi_cddb',
            host => 'mongodb://localhost:27017'
        },
    
        # load child doc classes
        classes => {
            self => 1, # loads CDDB::*
            load => ['Other::Namspace']
        }
    
    };
    
    1;
    
    package main ;
    
    use DateTime;
    
    my $cddb = CDDB->new;
    
    my $cds  = $cddb->class('album'); # grabs CDDB::Album
    
    # find cds released during or after the year 2000
    my $year_2000 = DateTime->now->set(year => 2000, month => 1, day => 1);

    my $search = $cds->search->where('released$gt' => $year_2000)->query;
    
    while (my $cd = $search->next) {
        
        print $cd->title, "\n";
        
    }

=head1 DESCRIPTION

Why MongoDB?
"MongoDB has the best features of document, key/value and relational
databases. --that was a period"

MongoDBI is an Object-Document-Mapper (ODM) for L<MongoDB>. It allows you to
create L<Moose>-based classes to interact with MongoDB databases. Born out of
the frustration from waiting for someone else to create a proper MongoDB access
layer, I decided to bite-the-bullet and try my hand at it.

At-a-glance, most will enjoy MongoDBI for its ability to easily model classes
while leveraging the power of MongoDB's schemaless and expeditios document-based
design, dynamic queries, and atomic modifier operations.

Also noteworthy is MongoDBI's ease-of-use, chainable search facilities,
automated indexing, moose-integration (inheritance support, etc), lean
document updates via dirty field tracking, and ability for each class to be
configured to use a different database and connection, etc.

Note! This library is still in its infancy and subject to change in code and
in the overall design. The POD (documentation) may also be lacking in certain
areas, for additional insight you may examine the accompanying tests.

This class, MongoDBI, sub-classes L<MongoDBI::Application>, please review that
module for more usage information.

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

