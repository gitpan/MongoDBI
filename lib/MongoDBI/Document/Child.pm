# ABSTRACT: A Relationship Wrapper Around MongoDBI Embedded Documents

use strict;
use warnings;

package MongoDBI::Document::Child;
{
    $MongoDBI::Document::Child::VERSION = '0.0.1';
}

use 5.001000;

our $VERSION = '0.0.1';    # VERSION

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

        $new_obj = $class->new(@args)

    }

    $self->config->{type} eq 'multiple'
      ? push @{$self->object}, $new_obj
      : $self->object($new_obj);

    return $new_obj;

}

sub count {

    my ($self) = @_;

    my $class = $self->target;

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

    my $class = $self->target;

    # return single object
    if ($self->config->{type} eq 'single') {

        return $self->object;

    }

    return undef unless "ARRAY" eq ref $self->object;

    # return selected objects
    if ($self->config->{type} eq 'multiple') {

        if (defined $length) {

            $offset ||= 0;

            return @{$self->object}[$offset .. $length];

        }

        elsif (defined $offset) {

            return $self->object->[$offset];

        }

    }

    return @{$self->object};

}

sub remove {

    my ($self, $offset, $length) = @_;

    my $class = $self->target;

    # return single object
    if ($self->config->{type} eq 'single') {

        my $child = $self->object;
        $self->object(undef);
        return $child;

    }

    return undef unless "ARRAY" eq ref $self->object;

    # return selected objects
    if ($self->config->{type} eq 'multiple') {

        if (defined $length) {

            $offset ||= 0;

            return splice @{$self->object}, $offset, $length;

        }

        elsif (defined $offset) {

            return delete $self->object->[$offset];

        }

    }

    my @objects = @{$self->object};
    $self->object(undef);

    return @objects;

}

1;

__END__

=pod

=head1 NAME

MongoDBI::Document::Child - A Relationship Wrapper Around MongoDBI Embedded Documents

=head1 VERSION

version 0.0.1

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

