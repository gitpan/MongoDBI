# ABSTRACT: Configuration for a MongoDBI Document Class

use strict;
use warnings;

package MongoDBI::Document::Config;
{
    $MongoDBI::Document::Config::VERSION = '0.0.1_01';
}

use 5.001000;

our $VERSION = '0.0.1_01';    # VERSION

use Moose::Role;              # is trait (++ :)

has _mongo_connection => (
    is  => 'rw',
    isa => 'MongoDB::Connection'
);

has _mongo_collection => (
    is  => 'rw',
    isa => 'MongoDB::Collection'
);

has collection => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { {} }
);

has database => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { {} }
);

has dirty_fields => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

has fields => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

has indexes => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] }
);

has scopes => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

sub set_database {
    my ($self, @args) = @_;

    my %args = @args == 1 ? (name => $args[0]) : @args;

    $args{name} ||= $self->database->{name};

    die "Please specify the name of the database" unless $args{name};

    $self->database->{$_} = $args{$_} for keys %args;

    return $self;
}

sub set_collection {
    my ($self, @args) = @_;

    my %args = @args == 1 ? (name => $args[0]) : @args;

    $args{name} 
      ||= $self->collection->{name}
      || delete $self->collection->{db_name}
      || $self->associated_class->{package};

    my %naming_template = (
        same       => sub { $_[0] },
        short      => sub { $_[0] =~ s{^.*\:\:(.*?)$}{$1}g; $_[0] },
        plural     => sub { $_[0] =~ s{^.*\:\:(.*?)$}{$1}g; lc "$_[0]s" },
        decamel    => sub { $_[0] =~ s{([a-z])([A-Z])}{$1_$2}g; lc $_[0] },
        undercolon => sub { $_[0] =~ s{\:\:}{_}g; lc $_[0] },
        lower      => sub { lc $_[0] },
        lc         => sub { lc $_[0] },
        upper      => sub { uc $_[0] },
        uc         => sub { uc $_[0] },
        default => sub {
            $_[0] =~ s{([a-z])([A-Z])}{$1_$2}g;
            $_[0] =~ s{\:\:}{_}g;
            lc "$_[0]s";
        }
    );

    # handle naming conventions
    $args{naming} ||= $self->collection->{naming}
      || 'default';

    $args{naming} = [$args{naming}] unless "ARRAY" eq ref $args{naming};

    foreach my $template (@{$args{naming}}) {
        $args{name} = $naming_template{$template}->($args{name});
    }

    $self->collection->{$_} = $args{$_} for keys %args;

    return $self;
}

1;
__END__

=pod

=head1 NAME

MongoDBI::Document::Config - Configuration for a MongoDBI Document Class

=head1 VERSION

version 0.0.1_01

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

