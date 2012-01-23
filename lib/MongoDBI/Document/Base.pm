# Base Class for a MongoDBI Document Class

use strict;
use warnings;

package MongoDBI::Document::Base;
{
  $MongoDBI::Document::Base::VERSION = '0.0.10';
}

use 5.001000;

our $VERSION = '0.0.10'; # VERSION

use Moose ('with');
use Moose::Exporter;
use MooseX::Traits;
use MongoDBI::Document::Sugar ();

my ($import, $unimport, $init_meta) = Moose::Exporter->build_import_methods(
    also             => [
        'Moose',
        'MongoDBI::Document::Sugar',
    ],
    base_class_roles => [
        'MongoDBI::Document::Storage',
        'MongoDBI::Document::Storage::Operation',
    ],
);

sub init_meta {
    my ($dummy, %opts) = @_;
    
    my $meta = Moose->init_meta(%opts);
    Moose::Util::MetaRole::apply_base_class_roles(
        for   => $opts{for_class},
        roles => [
            'MooseX::Traits',
            'MongoDBI::Document::Storage',
            'MongoDBI::Document::Storage::Operation',
        ]
    );
    
    # all document class instances should have an _dirty attribute
    # for tracking dirty columns as they are changed
    $meta->add_attribute(
        '_dirty' => (
            is => 'rw',
            isa => 'HashRef',
            default => sub {{
                
            }}
        )
    );
    
    # all document class instances should have an _id field
    # as they represent documents in a collection
    $meta->add_attribute(
        '_id' => (
            is => 'rw',
            isa => 'MongoDB::OID'
        )
    );
    
    # all document class instances should has a convenience
    # accessor for the special _id attr
    $meta->add_method(
        'id' => sub {
            my $self = shift ;
            return $self->_id ? $self->_id->value : 0;
        }
    );
    
    # all document class instances should be able to access
    # the special configuration attribute
    $meta->add_method(
        'config' => sub {
            shift->_config
        }
    );
    
    # determine whether and/or which fields have been changed
    $meta->add_method(
        'changed' => sub {
            my ($self, $field) = @_;
            return $field ?
                scalar (defined $self->_dirty->{$field}) :
                scalar (values %{ $self->_dirty }) ;
        }
    );
    
    # determine whether if/how fields have been changed
    $meta->add_method(
        'change' => sub {
            my ($self, $field) = @_;
            return $self->changed($field) ?
                $self->_dirty->{$field}->[-1] : 0 ;
        }
    );
    
    return Class::MOP::class_of($opts{for_class});
}

sub import {
    return unless $import;
    goto &$import;
}

sub unimport {
    return unless $unimport;
    goto &$unimport;
}

1;