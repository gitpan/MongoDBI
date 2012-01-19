# ABSTRACT: A GridFS Wrapper Around MongoDBI File Documents

use strict;
use warnings;

package MongoDBI::Document::GridFile;
{
  $MongoDBI::Document::GridFile::VERSION = '0.0.8';
}

use 5.001000;

our $VERSION = '0.0.8'; # VERSION

use Moose;
use IO::File;



has object      => ( is => 'rw', isa => 'Any' );


has parent      => ( is => 'rw', isa => 'Str', required => 1 );

has target      => ( is => 'rw', isa => 'MongoDB::GridFS' ); # not in service :)


has config      => ( is => 'rw', isa => 'HashRef', default => sub { {} } );


sub add {
    
    my ($self, @args) = @_;
    
    return unless @args;
    
    my $gridfs = $self->target;
    
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
        
        if ('IO::File' eq ref $args[0]) {
            
            $new_obj = $gridfs->insert($args[0]);
            
        }
        
        else {
            
            $new_obj = $gridfs->insert(new IO::File delete($args[0]), 'r');
            
        }
        
    }
    
    else {
        
        my %args = @args ;
    
        die "file (file path) attribute required" unless $args{file} ;
            
        my $file = 'IO::File' eq ref $args{file} ?
            delete $args{file} : new IO::File delete($args{file}), 'r';
        
        $new_obj = $gridfs->insert($file, { %args });
        
    }
    
    $self->config->{type} eq 'multiple' ?
        push @{$self->object}, $new_obj : $self->object($new_obj) ;
    
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
    
    my $parent  = $self->parent;
    my $gridfs  = $self->target;
    
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
    my $gridfs = $self->target;
    
    # inflate and return a gridfile object
    my $record = $gridfs->find_one({ _id => $mongo_oid });
    
    if ($record && $args{remove}) {
        
        $gridfs->remove({ _id => $mongo_oid }, { just_one => 1 });
        
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
        
        my $gridfile = $self->object; $self->object(undef);
        
        # cascade the removal
        $gridfile = $self->inflate($gridfile, remove => 1);
        
        return $gridfile;
        
    }
    
    return unless "ARRAY" eq ref $self->object;
    
    # return selected objects
    if ($self->config->{type} eq 'multiple') {
        
        if (defined $length) {
            
            $offset ||= 0;
            
            my @gridfiles = map { $self->inflate($_, remove => 1) }
                splice @{$self->object}, $offset, $length;
                
            return @gridfiles;
            
        }
        
        elsif (defined $offset) {
            
            my $gridfile = $self->inflate(
                delete $self->object->[$offset], remove => 1
            );
            
            return $gridfile;
            
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

MongoDBI::Document::GridFile - A GridFS Wrapper Around MongoDBI File Documents

=head1 VERSION

version 0.0.8

=head1 SYNOPSIS

    # create a relational/reference document relationship for CDDB::Album
    
    my $mp3s = MongoDBI::Document::GridFile->new(
        parent => 'CDDB::Track',
        config => { multiple => 1 }
    );
    
    $mp3s->add($path_or_io, ...); # 1st arg can be file_path or IO::File obj

=head1 DESCRIPTION

MongoDBI::Document::GridFile represents a MongoDB gridfs reference document
and is designed to be assigned to attributes in a parent document class.
MongoDBI::Document::GridFile provides a standardized API for handling
relationship concerns (e.g. adding, selecting, and removing related file
documents).

This relationship identification class is used automatically by the "file"
keyword provided by L<MongoDBI::Document::Sugar>.

The purpose of using this and other relationship identification/wrapper classes
is that it provides the MongoDBI serialization/deserialization mechanisms with a
standard API.

=head1 ATTRIBUTES

=head2 object

The object attribute can contain an instance of a L<MongoDB::OID> (or an array
of instances if the "multiple" configuration variable is true. You will likely
never need to access this attribute directly because access and manipulation of
the object(s) are made available through method calls.

=head2 parent

The parent attribute is required and should contain the fully-qualified class
name of the parent document class. Once set you will likely never need to access
this attribute directly.

=head2 config

The config attribute can contain a hashref of key/value arguments which control
how method calls manipulate the class instance(s) stored in the object attribute.

    # forces the object attribute to become an arrayref having instances
    # append the object attribute
    
    MongoDBI::Document::GridFile->new(
        ...,
        config => { multiple => 1 }
    );

=head1 METHODS

=head2 add

The add method requires an absolute file path and optional key/value parameters
which will be saved along-side of the gridfs document.

The add method adds, replaces or appends the object attribute based on the
configuration in the config attribute.

    my $mp3s = MongoDBI::Document::GridFile->new(
        ..., config => { multiple => 1 }
    );
    
    $mp3s->add($file1, ...);
    $mp3s->add($file2, ...);
    $mp3s->add($file3, ...); # we've added three files
    
    my $mp3s = MongoDBI::Document::Relative->new(
        ..., config => {  }
    );
    
    $mp3s->add($file1, ...);
    $mp3s->add($file2, ...); # we've replace the original file

The optional arguments passed to the add method can be arbitrary and will be
saved in the gridfs along-side the file. It is important that you understand
that those arbitrary parameters will not be saved on the parent document.
Querying for the file based on those arbitrary parameters must be done on the
gridfs collection related to the parent.

=head2 count

The count method simply returns the number of objects existing in the object
attribute.

    my $mp3s = MongoDBI::Document::GridFile->new(
        ..., config => { multiple => 1 }
    );
    
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...); 
    
    $mp3s->count(); # we've added three files

=head2 get

The get method retrieves a particular object instance from the object attribute
(store), if configured for multiple objects, it accepts an index (starting at 0)
which will return the object instance at that position, or a starting and ending
index which returns object instances within that range.

    my $mp3s = MongoDBI::Document::GridFile->new(
        ..., config => { multiple => 1 }
    );
    
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...); 
    
    my $mp31 = $mp3s->get(0);
    my @mp3s_first5 = $mp3s->get(0, 4);

=head2 remove

The remove method retrieves and removes a particular object instance from the
object attribute (store), if configured for multiple objects, it accepts an
index (starting at 0) which will delete and return the object instance at that
position, or a starting and ending index which deletes and returns object
instances within that range (as you would expect the native Perl splice function
to operate).

    my $mp3s = MongoDBI::Document::Relative->new(
        ..., config => { multiple => 1 }
    );
    
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...);
    $mp3s->add(...); # added 9 tracks
    
    my $mp31 = $mp3s->remove(0);
    my @mp3s_next5 = $mp3s->remove(0, 4);
    
    print $mp3s->count; # prints 3

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

