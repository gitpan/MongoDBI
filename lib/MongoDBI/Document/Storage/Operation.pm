# ABSTRACT: Standard MongoDBI Document/Collection Operations

use strict;
use warnings;

package MongoDBI::Document::Storage::Operation;
{
    $MongoDBI::Document::Storage::Operation::VERSION = '0.0.1_02';
}

use 5.001000;

our $VERSION = '0.0.1_02';    # VERSION

use Moose::Role;

use MongoDB::OID;
use MongoDBI::Document::Storage::Criterion;
use MongoDBI::Document::Child;

sub all {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where) if values %where;

    return $search->query->all;

}

sub clone {

    my ($self, %options) = @_;

    $self->is_instance('clone');

    die "clone can only be performed on an instance " . "with an ID"
      unless $self->id;

    my $attributes = $self->collapse;

    delete $attributes->{_id};

    my $class = ref $self;
    my $clone = $class->new(%{$attributes});

    return $clone;

}

sub collapse {

    my $self = shift;
    my $data = {};

    # in an attempt to achieve maxium efficiency, only collapse dirty fields
    while (my ($field, $changes) = each(%{$self->_dirty})) {

        $data->{$field} = $changes->[-1]->{new_value};

    }

    # collapse embedded doc classes
    while (my ($name, $config) = each(%{$self->config->fields})) {

        # collapse embedded documents
        if ($config->{isa} eq 'MongoDBI::Document::Child') {

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

                    my $class = $self->$name->target;

                    foreach my $object (@{$self->$name->object}) {

                        push @{$data->{$name}},
                          { '$id'  => $object,
                            '$ref' => $class->config->collection->{name}
                          };

                    }

                }

            }

        }

        # additionally, be mindful of fields with default values
        # if they had been set by the app, they'd be marked as dirty and
        # should exist in $data
        if (!defined $data->{$name} && $config->{default}) {

            $data->{$name} =
              "CODE" eq ref $config->{default}
              ? $config->{default}->($self)
              : $config->{default};

        }

    }

    # add id if applicable
    $data->{'_id'} = $self->_id if $self->id;

    return $data;

}

sub collection {

    my $class = shift;

    $class = ref $class if ref $class;

    return $class->config->_mongo_collection;

}

sub connection {

    my $class = shift;

    $class = ref $class if ref $class;

    return $class->config->_mongo_connection;

}

sub count {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where) if values %where;

    return $search->query->count;

}

sub create {

    my ($class, %args) = @_;

    $class = ref $class if ref $class;

    my $new = $class->new(%args);

    $new->insert;

    return $new;

}

sub expand {

    my ($class, %data) = @_;

    my %args = ();    # expanded attribute data

    # expand $data into class attributes
    while (my ($name, $config) = each(%{$class->config->fields})) {

        if ($config->{isa} eq 'MongoDBI::Document::Child') {

            if ($config->{type} eq 'single') {

                my %child_args = %{$config};
                delete $child_args{class};
                my $child = MongoDBI::Document::Child->new(
                    parent => ref $class || $class,
                    target => $config->{class},
                    config => {%child_args},
                );

                $child->add(%{$data{$name}});

                $args{$name} = $child;

            }

            if ($config->{type} eq 'multiple') {

                if ("ARRAY" eq ref $data{$name}) {

                    my %child_args = %{$config};
                    delete $child_args{class};
                    my $child = MongoDBI::Document::Child->new(
                        parent => ref $class || $class,
                        target => $config->{class},
                        config => {%child_args},
                    );

                    foreach my $doc (@{$data{$name}}) {

                        $child->add(%{$doc});

                    }

                    $args{$name} = $child;

                }

            }

        }

        elsif ($config->{isa} eq 'MongoDBI::Document::Relative') {

            if ($config->{type} eq 'single') {

                my %relative_args = %{$config};
                my $relative      = MongoDBI::Document::Relative->new(
                    parent => ref $class || $class,
                    target => $config->{class},
                    config => {%relative_args},
                );

                $relative->object($data{$name}->{'$id'});

                $args{$name} = $relative;

            }

            if ($config->{type} eq 'multiple') {

                if ("ARRAY" eq ref $data{$name}) {

                    my %relative_args = %{$config};
                    delete $relative_args{class};
                    my $relative = MongoDBI::Document::Relative->new(
                        parent => ref $class || $class,
                        target => $config->{class},
                        config => {%relative_args},
                    );

                    foreach my $doc (@{$data{$name}}) {

                        $relative->object([])
                          unless "ARRAY" eq ref $relative->object;

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
    if ($data{_id}) {

        if (ref $data{_id}) {
            $args{_id} = $data{_id};
        }
        else {
            $args{_id} = MongoDB::OID->new(value => $data{'_id'});
        }

    }

    return %args;

}

sub find {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where) if values %where;

    return $search->query;

}

sub find_one {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where) if values %where;
    $search->limit(-1);

    my $data = $search->query->next;

    return $data ? $class->new($class->expand(%{$data})) : undef;

}

sub find_or_create {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $instance = $class->find_one(%where);

    return $instance ? $instance : $class->create(%where);

}

sub find_or_new {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $instance = $class->find_one(%where);

    return $instance ? $instance : $class->new($class->expand(%where));

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

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where) if values %where;
    $search->limit(-1);
    $search->asc_sort('_id');

    my $data = $search->query->next;

    return $data ? $class->new($class->expand(%{$data})) : undef;

}

sub insert {

    my ($self, %options) = @_;

    $self->is_instance('insert');

    die "insert cannot be performed on an instance "
      . "with an ID ("
      . $self->id . ")"
      if $self->id;

    $self->connect unless $self->config->database->{connected};

    my $collection = $self->config->_mongo_collection;

    $self->_id($collection->insert($self->collapse, %options));

    return $self;

}

sub is_instance {

    my ($self, $op) = @_;

    $op ||= "this operation";

    die $op
      . " can only be performed on an instance, "
      . "try using "
      . ($self || 'Class')
      . "->new(...);"

      unless ref $self;

    return $self;

}

sub last {

    my ($class, @where) = @_;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

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

sub page {

    my ($class, @args) = @_;

    my $skip  = pop @args;
    my $limit = pop @args;

    my @where = @args;

    my %where =
      @where == 1 ? (_id => MongoDB::OID->new(value => $where[0])) : @where;

    $class = ref $class if ref $class;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where) if values %where;
    $search->limit($limit);
    $search->skip($skip);

    return $search->query;

}

sub reload {

    my ($self) = @_;

    $self->is_instance('reload');

    die "reload can only be performed on an instance " . "with an ID"
      unless $self->id;

    my %where = (_id => $self->_id);

    my $class = ref $self;

    $class->connect unless $class->config->database->{connected};

    my $search = $class->search;
    $search->where(%where);
    $search->limit(-1);

    my $data = $search->query->next;

    return $data ? $class->new($class->expand(%{$data})) : undef;

}

sub remove {

    my ($self, %options) = @_;

    $self->is_instance('remove');

    die "remove can only be performed on an instance " . "with an ID"
      unless $self->id;

    $self->connect unless $self->config->database->{connected};

    my $collection = $self->config->_mongo_collection;

    $collection->remove({_id => $self->_id}, %options);

    # no longer assoc to a record
    $self->_id->{value} = 0;

    # leaving dirty tracking in-tact

    return $self;

}

sub save {

    my ($self, %options) = @_;

    $self->is_instance('save');

    die "save cannot be performed on an instance " . "without an ID"
      unless $self->id;

    die "save cannot be performed on an instance " . "without any altered keys"
      unless values %{$self->_dirty};

    $self->connect unless $self->config->database->{connected};

    my $collection = $self->config->_mongo_collection;

    $collection->save($self->collapse, %options);

    return $self;

}

sub search {

    my ($self) = @_;

    my $config = $self->config;

    confess("config attribute not present") unless blessed($config);

    $self->connect unless $config->database->{connected};

    return MongoDBI::Document::Storage::Criterion->new(
        collection => $config->_mongo_collection);

}

sub update {

    my ($self, %options) = @_;

    $self->is_instance('update');

    die "update cannot be performed on an instance " . "without an ID"
      unless $self->id;

    die "update cannot be performed on an instance "
      . "without any altered keys"
      unless values %{$self->_dirty};

    $self->connect unless $self->config->database->{connected};

    my $collection = $self->config->_mongo_collection;

    $options{upsert}   ||= 0;
    $options{multiple} ||= 1;

    $collection->update({_id => $self->_id}, $self->collapse, {%options});

    return $self;

}

no Moose::Role;

1;
__END__

=pod

=head1 NAME

MongoDBI::Document::Storage::Operation - Standard MongoDBI Document/Collection Operations

=head1 VERSION

version 0.0.1_02

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

