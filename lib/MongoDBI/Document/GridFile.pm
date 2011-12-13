# ABSTRACT: A GridFS Wrapper Around MongoDBI File Documents

use strict;
use warnings;

package MongoDBI::Document::GridFile;
{
  $MongoDBI::Document::GridFile::VERSION = '0.0.2';
}

use 5.001000;

our $VERSION = '0.0.2'; # VERSION

use Moose;
use IO::File;

has object      => ( is => 'rw', isa => 'Any' );
has parent      => ( is => 'rw', isa => 'Str' );
has target      => ( is => 'rw', isa => 'MongoDB::GridFS' );
has config      => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

sub add {
    
    my ($self, @args) = @_;
    
    return undef unless @args;
    
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
    
    return undef unless "ARRAY" eq ref $self->object;
    
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
    
    return undef unless "ARRAY" eq ref $self->object;
    
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

version 0.0.2

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

