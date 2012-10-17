# ABSTRACT: MongoDBI Chainable Collection Query Builder

use strict;
use warnings;

package MongoDBI::Document::Storage::Cursor;
{
    $MongoDBI::Document::Storage::Cursor::VERSION = '0.02';
}

use Moose;
use boolean;

use 5.001000;

our $VERSION = '0.02';    # VERSION


has cursor => (
    is       => 'ro',
    isa      => 'MongoDB::Cursor',
    required => 1,
    handles  => [
        qw/
          started_iterating
          immortal
          tailable
          partial
          slave_okay

          fields
          sort
          limit
          skip
          snapshot
          hint
          explain
          count
          reset
          has_next
          info
          /
    ],
);

has build_class => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub next {
    my ($self) = @_;

    my $doc = $self->cursor->next;

    if ($doc) {
        my $class = $self->build_class;
        return $class->new($class->expand(%$doc));
    }
    else {
        return;
    }
}

sub all {
    my ($self) = @_;

    my @ret;
    while (my $obj = $self->next) {
        push @ret, $obj;
    }

    return @ret;
}

1;

__END__
=pod

=head1 NAME

MongoDBI::Document::Storage::Cursor - MongoDBI Chainable Collection Query Builder

=head1 VERSION

version 0.02

=head1 SYNOPSIS

    my $cursor = MongoDBI::Document::Storage::Cursor->new( $mongo_cursor );
    
		$cursor->has_next(...)
		$cursor->next(...)
		$cursor->all(...)
    
    See MongoDB::Cursor for more methods.
		MongoDBI::Document::Storage::Cursor supports all methods, via delegation, that MongoDB::Cursor provides.

=head1 DESCRIPTION

MongoDBI::Document::Storage::Cursor provides a wrapper around MongoDB::Cursor that allows you to retrieve
objects from a MongoDB::Cursor.

=head1 AUTHORS

=over 4

=item *

Al Newkirk <awncorp@cpan.org>

=item *

Robert Grimes <buu@erxz.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

