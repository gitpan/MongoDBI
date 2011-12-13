# ABSTRACT: MongoDBI Chainable Collection Query Builder

use strict;
use warnings;

package MongoDBI::Document::Storage::Criterion;
{
  $MongoDBI::Document::Storage::Criterion::VERSION = '0.0.2';
}

use Moose;

use 5.001000;

our $VERSION = '0.0.2'; # VERSION

has collection => (
    is       => 'ro',
    isa      => 'MongoDB::Collection',
    required => 1
);

has criteria => (
    is       => 'rw',
    isa      => 'HashRef',
    default  => sub {{
        select   => {},
        where    => {},
        order    => {},
        options  => {}
    }}
);

sub arg_parser {
    
    my %args = @_;
    
    foreach my $key ( keys %args ) {
        
        if ($key =~ /(\$[a-z]+)$/) {
            
            my $symbol = $1;
            my $regex  = '\\'.$1;
            
            $key =~ s/$regex$//;
            
            if ($symbol eq '$btw') {
                
                my $values = delete $args{"$key$symbol"}; # arrayref
                
                $args{$key} = { '$gte' => $values->[0], '$lte' => $values->[1] };
                
            }
            
            else {
                
                $args{$key} = { $symbol => delete $args{"$key$symbol"} };
                
            }
            
        }
        
    }
    
    return %args;
    
}

sub all_in {
    
    my ($self, $key, @values) = @_;
    
    foreach my $value ( @values ) {
        
        push @{$self->criteria->{where}->{$key}->{'$all'}},
            "ARRAY" eq ref $value? @{$value} : $value;
        
    }
    
    return $self;
    
}

sub all_of {
    
    my ($self, @args) = @_;
    
    for (my $i = 0; $i < @args; $i++) {
        
        my ($key, $value) = ($args[$i], $args[++$i]);
        
        push @{$self->criteria->{where}->{'$and'}},
            { arg_parser($key => $value) };
        
    }
    
    return $self;
    
}

sub and_where {
    
    my ($self, @args) = @_;
    
    for (my $i = 0; $i < @args; $i++) {
        
        my ($key, $value) = ($args[$i], $args[++$i]);
        
        push @{$self->criteria->{where}->{'$and'}},
            { arg_parser($key => $value) };
        
    }
    
    return $self;
    
}

sub any_in {
    
    my ($self, $key, @values) = @_;
    
    foreach my $value ( @values ) {
        
        push @{$self->criteria->{where}->{$key}->{'$in'}},
            "ARRAY" eq ref $value? @{$value} : $value;
        
    }
    
    return $self;
    
}

sub any_of {
    
    my ($self, $key, @values) = @_;
    
    foreach my $value ( @values ) {
        
        push @{$self->criteria->{where}->{$key}->{'$or'}},
            "ARRAY" eq ref $value? @{$value} : $value;
        
    }
    
    return $self;
    
}

sub asc_sort {
    
    my ($self, @args) = @_;
    
    foreach my $key ( @args ) {
        
        $self->criteria->{order}->{$key} = 1;
        
    }
    
    return $self;
    
}

sub desc_sort {
    
    my ($self, @args) = @_;
    
    foreach my $key ( @args ) {
        
        $self->criteria->{order}->{$key} = -1;
        
    }
    
    return $self;
    
}

sub distinct {
    
    my ($self, @keys) = @_;
    
    foreach my $key ( @keys ) {
        
        $self->criteria->{options}->{distinct}->{$key} = 1;
        
    }
    
    return $self;
    
}

sub exists {
    
    my ($self, @keys) = @_;
    
    foreach my $key ( @keys ) {
        
        $self->where($key => qr/./);
        
    }
    
    return $self;
    
}

sub limit {
    
    my ($self, $limit) = @_;
    
    $self->criteria->{options}->{limit} = $limit if $limit ;
    
    return $self;
    
}

sub near {
    
    my ($self, $key, @values) = @_;
    
    foreach my $value ( @values ) {
        
        push @{$self->criteria->{where}->{$key}->{'$near'}},
            "ARRAY" eq ref $value? @{$value} : $value;
        
    }
    
    return $self;
    
}

sub never {
    
    my ($self, @args) = @_;
    
    foreach my $key ( @args ) {
        
        $self->criteria->{select}->{$key} = '0';
        
    }
    
    return $self;
    
}

sub not_in {
    
    my ($self, $key, @values) = @_;
    
    foreach my $value ( @values ) {
        
        push @{$self->criteria->{where}->{$key}->{'$nin'}},
            "ARRAY" eq ref $value? @{$value} : $value;
        
    }
    
    return $self;
    
}

sub only {
    
    my ($self, @args) = @_;
    
    foreach my $key ( @args ) {
        
        $self->criteria->{select}->{$key} = 1;
        
    }
    
    return $self;
    
}

sub or_where {
    
    my ($self, @args) = @_;
    
    for (my $i = 0; $i < @args; $i++) {
        
        my ($key, $value) = ($args[$i], $args[++$i]);
        
        push @{$self->criteria->{where}->{'$or'}},
            { arg_parser($key => $value) };
        
    }
    
    return $self;
    
}

sub query {
    
    my $self = shift;
    
    my $cri = $self->criteria;
    my $col = $self->collection;
    my $cur = $col->query($cri->{where});
       
       $cur->fields($cri->{select}) if values %{$cri->{select}};
       $cur->sort($cri->{order}) if values %{$cri->{order}};
       $cur->limit($cri->{options}->{limit}) if $cri->{options}->{limit};
       $cur->skip($cri->{options}->{skip}) if $cri->{options}->{skip};
    
    return $cur;
    
}

sub skip {
    
    my ($self, $skip) = @_;
    
    $self->criteria->{options}->{skip} = $skip if $skip ;
    
    return $self;
    
}

sub sort {
    
    my ($self, %args) = @_;
    
    while (my ($key, $value) = each ( %args )) {
        
        $self->criteria->{order}->{$key} = $value;
        
    }
    
    return $self;
    
}

sub where {
    
    my ($self, %args) = @_;
    
    %args = arg_parser %args;
    
    while (my ($key, $value) = each ( %args )) {
        
        $self->criteria->{where}->{$key} = $value;
        
    }
    
    return $self;
    
}

1;
__END__
=pod

=head1 NAME

MongoDBI::Document::Storage::Criterion - MongoDBI Chainable Collection Query Builder

=head1 VERSION

version 0.0.2

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

