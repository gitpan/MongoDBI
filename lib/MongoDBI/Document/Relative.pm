# A Relationship Wrapper Around MongoDBI Relational Documents

use strict;
use warnings;

package MongoDBI::Document::Relative;
{
    $MongoDBI::Document::Relative::VERSION = '0.0.1_02';
}

use 5.001000;

our $VERSION = '0.0.1_02';    # VERSION

use Moose;

has object => (is => 'rw', isa => 'Any');
has parent => (is => 'rw', isa => 'Str');
has target => (is => 'rw', isa => 'Str');
has config => (is => 'rw', isa => 'HashRef', default => sub { {} });

sub add {

    my ($self, @args) = @_;

    return undef unless @args;

    my $class = $self->target;

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

    my $new_obj;

    if (@args == 1) {

        die "cannot add/embed an object that is not a $class"
          unless $class eq ref $args[0];

        $new_obj = $args[0];

    }

    else {

        $new_obj = $class->find_or_create(@args)

    }

    $self->config->{type} eq 'multiple'
      ? push @{$self->object}, $new_obj->_id
      : $self->object($new_obj->_id);

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

    return undef unless "ARRAY" eq ref $self->object;

    # return selected objects
    if ($self->config->{type} eq 'multiple') {

        if (defined $length) {

            $offset ||= 0;

            return
              map { $self->inflate($_) } @{$self->object}[$offset .. $length];

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

        $cfg->database($parent->config->database);
        $cfg->set_database;
        $cfg->set_collection unless values %{$cfg->collection};

        my $database_name   = $cfg->database->{name};
        my $collection_name = $cfg->collection->{'name'};

        my $con = $parent->config->_mongo_connection;
        my $db  = $con->get_database($database_name);
        my $col = $db->get_collection($collection_name);

        $cfg->_mongo_collection($col);
        $cfg->_mongo_connection($con);

        $cfg->database->{connected} = 1;

        # apply index instructions
        foreach my $spec (@{$cfg->indexes}) {

            # spell-it-out so the references aren't altered
            $col->ensure_index({%{$spec->[0]}}, {%{$spec->[1]}});
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

        my $relative = $self->object;
        $self->object(undef);

        # cascade the removal
        $relative = $self->inflate($relative, remove => 1);

        return $relative;

    }

    return undef unless "ARRAY" eq ref $self->object;

    # return selected objects
    if ($self->config->{type} eq 'multiple') {

        if (defined $length) {

            $offset ||= 0;

            my @relatives =
              map { $self->inflate($_, remove => 1) } splice @{$self->object},
              $offset, $length;

            return @relatives;

        }

        elsif (defined $offset) {

            my $relative =
              $self->inflate(delete $self->object->[$offset], remove => 1);

            return $relative;

        }

    }

    my @objects = map { $self->inflate($_, remove => 1) } @{$self->object};

    $self->object(undef);

    return @objects;

}

1;
