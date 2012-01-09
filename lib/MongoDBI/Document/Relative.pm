# ABSTRACT: A Relationship Wrapper Around MongoDBI Relational Documents

use strict;
use warnings;

package MongoDBI::Document::Relative;
{
  $MongoDBI::Document::Relative::VERSION = '0.0.7';
}

use 5.001000;

our $VERSION = '0.0.7'; # VERSION

use Moose;



has object      => ( is => 'rw', isa => 'Any' );


has parent      => ( is => 'rw', isa => 'Str', required => 1 );


has target      => ( is => 'rw', isa => 'Str', required => 1 );


has config      => ( is => 'rw', isa => 'HashRef', default => sub { {} } );


sub add {
    
    my ($self, @args) = @_;
    
    return unless @args;
    
    my $class = $self->target;
    
    $self->integrity;
    
    # if object type changes from single to multiple
    if ($self->config->{type} eq 'multiple') {
        
        if (defined $self->object) {
            
            unless ("ARRAY" eq ref $self->object) {
                
                $self->object([$self->object]);
                
            }
            
        }
        
        else {
            
            $self->object([]);
            
        }
        
    }
    
    my $new_obj ;
    
    if (@args == 1) {
        
        die "cannot add/embed an object that is not a $class"
            unless $class eq ref $args[0];
            
        $new_obj = $args[0];
        
    }
    
    else {
        
        $new_obj = $class->create(@args)
        
    }
    
    $self->config->{type} eq 'multiple' ?
        push @{$self->object}, $new_obj->_id : $self->object($new_obj->_id) ;
    
    return $new_obj;
    
}


sub count {
    
    my ($self) = @_;
    
    my $parent = $self->parent;
    my $class  = $self->target;
    
    # return single object count
    if ($self->config->{type} eq 'single') {
        
        return defined $self->object ? 1 : 0;
        
    }
    
    return 0 unless "ARRAY" eq ref $self->object;
    
    # return multi object count
    if ($self->config->{type} eq 'multiple') {
        
        return @{$self->object};
        
    }
    
    return 0;
    
}


sub get {
    
    my ($self, $offset, $length) = @_;
    
    my $parent = $self->parent;
    my $class  = $self->target;
    
    # return single object
    if ($self->config->{type} eq 'single') {
        
        return $self->inflate($self->object);
        
    }
    
    return unless "ARRAY" eq ref $self->object;
    
    # return selected objects
    if ($self->config->{type} eq 'multiple') {
        
        if (defined $length) {
            
            $offset ||= 0;
            
            return map { $self->inflate($_) } @{$self->object}[$offset..$length];
            
        }
        
        elsif (defined $offset) {
            
            return $self->inflate($self->object->[$offset]);
            
        }
        
    }
    
    return map { $self->inflate($_) } @{$self->object};
    
}

sub inflate {
    
    my ($self, $mongo_oid, %args) = @_;
    
    my $parent = $self->parent;
    my $class  = $self->target;
    
    # inflate and return a relative object
    my $record = $class->find_one($mongo_oid->value);
    
    if ($record && $args{remove}) {
        
        $record->remove;
        
    }

    return $record;
    
}

sub integrity {
    
    my $self = shift;
    
    my $parent = $self->parent;
    my $class  = $self->target;
    
    # the transfer of power
    unless (values %{$class->config->database}) {
        
        # almost a cut-n-paste of the storage connect method
        # need to figure out a better way to do this
        
        my $cfg = $class->config;
        
        $cfg->database($parent->config->database) ;
        $cfg->set_database ;
        $cfg->set_collection unless values %{$cfg->collection};
        
        my $database_name   = $cfg->database->{name};
        my $collection_name = $cfg->collection->{'name'} ;
        
        my $con  = $parent->config->_mongo_connection;
        my $db   = $con->get_database( $database_name );
        my $col  = $db->get_collection( $collection_name );
        
        $cfg->_mongo_collection($col);
        $cfg->_mongo_connection($con);
        
        $cfg->database->{connected} = 1;
        
        # apply index instructions
        foreach my $spec (@{$cfg->indexes}) {
            # spell-it-out so the references aren't altered
            $col->ensure_index({%{$spec->[0]}},{%{$spec->[1]}});
        }
        
    }
    
    return $self;
    
}


sub remove {
    
    my ($self, $offset, $length) = @_;
    
    my $parent = $self->parent;
    my $class  = $self->target;
    
    $self->integrity;
    
    # return single object
    if ($self->config->{type} eq 'single') {
        
        my $relative = $self->object; $self->object(undef);
        
        # cascade the removal
        $relative = $self->inflate($relative, remove => 1);
        
        return $relative;
        
    }
    
    return unless "ARRAY" eq ref $self->object;
    
    # return selected objects
    if ($self->config->{type} eq 'multiple') {
        
        if (defined $length) {
            
            $offset ||= 0;
            
            my @relatives = map { $self->inflate($_, remove => 1) }
                splice @{$self->object}, $offset, $length;
                
            return @relatives;
            
        }
        
        elsif (defined $offset) {
            
            my $relative = $self->inflate(
                delete $self->object->[$offset], remove => 1
            );
            
            return $relative;
            
        }
        
    }
    
    my @objects = map { $self->inflate($_, remove => 1) } @{$self->object};
    
    $self->object(undef) ;
    
    return @objects;
    
}

1;

__END__
=pod

=head1 NAME

MongoDBI::Document::Relative - A Relationship Wrapper Around MongoDBI Relational Documents

=head1 VERSION

version 0.0.7

=head1 SYNOPSIS

    # create a relational/reference document relationship for CDDB::Album
    
    my $tracks = MongoDBI::Document::Relative->new(
        parent => 'CDDB::Album',
        target => 'CDDB::Track',
        config => { multiple => 1 }
    );
    
    $tracks->add(...); 

=head1 DESCRIPTION

MongoDBI::Document::Relative represents a MongoDB relational/reference document
and is designed to be assigned to attributes in a parent document class.
MongoDBI::Document::Relative provides a standardized API for handling
relationship concerns (e.g. adding, selecting, and removing related documents).

This relationship identification class is used automatically by the "has_one",
"has_many", and "belongs_to" keywords provided by L<MongoDBI::Document::Sugar>.

The purpose of using this and other relationship identification/wrapper classes
is that it provides the MongoDBI serialization/deserialization mechanisms with a
standard API.

=head1 ATTRIBUTES

=head2 object

The object attribute can contain an instance of the class target (or an array of
instances if the "multiple" configuration variable is true. You will likely
never need to access this attribute directly because access and manipulation of
the object(s) are made available through method calls.

=head2 parent

The parent attribute is required and should contain the fully-qualified class
name of the parent document class. Once set you will likely never need to access
this attribute directly.

=head2 target

The target attribute is required and should contain the fully-qualified class
name of the document class to be used as a relational document class. Once set
you will likely never need to access this attribute directly.

=head2 config

The config attribute can contain a hashref of key/value arguments which control
how method calls manipulate the class instance(s) stored in the object attribute.

    # forces the object attribute to become an arrayref having instances
    # append the object attribute
    
    MongoDBI::Document::Relative->new(
        ...,
        config => { multiple => 1 }
    );

=head1 METHODS

=head2 add

The add method expects key/value arguments which will be passed to the create
method of the class defined in the target attribute, or, a single argument which
must be an instance of the class defined in the target attribute.

The add method adds, replaces or appends the object attribute based on the
configuration in the config attribute.

    my $tracks = MongoDBI::Document::Relative->new(
        ..., config => { multiple => 1 }
    );
    
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...); # we've added three tracks
    
    my $tracks = MongoDBI::Document::Relative->new(
        ..., config => {  }
    );
    
    $tracks->add(...);
    $tracks->add(...); # we've replace the original track

The arguments passed to the add method must be attributes existing on the class
defined in the target attribute.

=head2 count

The count method simply returns the number of objects existing in the object
attribute.

    my $tracks = MongoDBI::Document::Relative->new(
        ..., config => { multiple => 1 }
    );
    
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...); 
    
    $tracks->count(); # we've added three tracks

=head2 get

The get method retrieves a particular object instance from the object attribute
(store), if configured for multiple objects, it accepts an index (starting at 0)
which will return the object instance at that position, or a starting and ending
index which returns object instances within that range.

    my $tracks = MongoDBI::Document::Relative->new(
        ..., config => { multiple => 1 }
    );
    
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...); 
    
    my $track1 = $tracks->get(0);
    my @tracks_first5 = $tracks->get(0, 4);

=head2 remove

The remove method retrieves and removes a particular object instance from the
object attribute (store), if configured for multiple objects, it accepts an
index (starting at 0) which will delete and return the object instance at that
position, or a starting and ending index which deletes and returns object
instances within that range (as you would expect the native Perl splice function
to operate).

    my $tracks = MongoDBI::Document::Relative->new(
        ..., config => { multiple => 1 }
    );
    
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...);
    $tracks->add(...); # added 9 tracks
    
    my $track1 = $tracks->remove(0);
    my @tracks_next5 = $tracks->remove(0, 4);
    
    print $tracks->count; # prints 3

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

