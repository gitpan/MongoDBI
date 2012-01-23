# ABSTRACT: MongoDBI Chainable Collection Query Builder

use strict;
use warnings;

package MongoDBI::Document::Storage::Criterion;
{
  $MongoDBI::Document::Storage::Criterion::VERSION = '0.0.10';
}

use Moose;
use boolean;

use 5.001000;

our $VERSION = '0.0.10'; # VERSION



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
        
        if ($key =~ /[^\$ ](\$[a-z]+)$/) {
            
            my $symbol = $1;
            my $regex  = '\\'.$1;
            
            $key =~ s/$regex$//;
            
            if ($symbol eq '$btw') {
                
                my $values = delete $args{"$key$symbol"}; # arrayref
                
                $args{$key} = { '$gte' => $values->[0], '$lte' => $values->[1] };
                
            }
            
            else {
                
                $args{$key}->{$symbol} = delete $args{"$key$symbol"};
                
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
        
        push @{$self->criteria->{where}->{'$or'}}, "ARRAY" eq ref $value?
            map {{ $key => $_ }} @{$value} : { $key => $value };
        
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

# NEEDS POD, ONCE I FIND THE RIGHT APPROACH

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


sub page {
    
    my ($self, $limit, $skip) = @_;
    
    $skip ||= 0;
    
    my $page = $limit * $skip;
    
    $self->limit($limit);
    
    $self->skip($page);
    
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


sub where_exists {
    
    my ($self, @args) = @_;
    
    foreach my $key ( @args ) {
        
        $self->criteria->{where}->{$key}->{'$exists'} = boolean::true;
        
    }
    
    return $self;
    
}


sub where_not_exists {
    
    my ($self, @args) = @_;
    
    foreach my $key ( @args ) {
        
        $self->criteria->{where}->{$key}->{'$exists'} = boolean::false;
        
    }
    
    return $self;
    
}

1;
__END__
=pod

=head1 NAME

MongoDBI::Document::Storage::Criterion - MongoDBI Chainable Collection Query Builder

=head1 VERSION

version 0.0.10

=head1 SYNOPSIS

    my $search = MongoDBI::Document::Storage::Criterion->new(
        collection => $mongdb_collection
    );
    
    $search->all_in(...);
    $search->all_of(...);
    $search->also_in(...);
    $search->any_in(...);
    $search->any_of(...);
    $search->asc_sort(...);
    $search->desc_sort(...);
    $search->select(...);
    
    ... etc
    
    my $search = CDDB::Album->search;
       $search = $search->where('released$lt' => DateTime->now->set(...));
       $search = $search->asc_sort('title')->limit(25);
       
    my $mongodb_cursor = $search->query;

=head1 DESCRIPTION

MongoDBI::Document::Storage::Criterion provides MongoDBI with a chainable object
for building complex and dynamic queries. The querying object will never hit the
database until you ask it to.

=head1 ATTRIBUTES

=head2 collection

The collection attribute is a reference to a L<MongoDB::Collection> object. You
will not likely need to access this directly.

=head2 criteria

The criteria attribute is a hashref which represents the current query.

=head1 METHODS

=head2 all_in

The all_in method adds a criterion that specifies values that must all match
in order to return results. The corresponding MongoDB operation is $all.

    $search->all_in(aliases => '007', 'Bond');
    
    ... { "aliases" : { "$all" : ['007', 'Bond'] } }

=head2 all_of

The all_of method adds a criterion that specifies expressions that must all
match in order to return results. The corresponding MongoDB operation is $and.

    $search->all_of('age$gt' => 60, emp_status => 'retired');
    
    ... { "$and" : { "age" : { "$gt" : 60 }, "emp_status" : "retired" } }

=head2 and_where

The and_where method wraps and appends the where criterion.

    $search->and_where('age$gte' => 21);
    $search->and_where('age$lte' => 60);
    
    ... { "$and" : [{ "age" : { "$gte" : 21 }, "age" : { "$lte" : 60 } }] }

=head2 any_in

The any_in method adds a criterion that specifies values where any value can
match in order to return results. The corresponding MongoDB operation is $in.

    $search->any_in(aliases => '007', 'Bond');
    
    ... { "aliases" : { "$in" : ['007', 'Bond'] } }

=head2 any_of

The any_of method adds a criterion that specifies a set of expressions that any
can match in order to return results. The underlying MongoDB expression is $or.

    $search->any_of(last_name => 'Penn', 'Teller');
    
    ... { "$or" : [{ "last_name" : "Penn" }, { "last_name" : "Teller" }] }

=head2 asc_sort

The asc_sort method adds a criterion that instructs the L<MongoDB::Collection>
query method to sort the results on specified key in ascending order.

    $search->asc_sort('first_name', 'last_name');

=head2 desc_sort

The desc_sort method adds a criterion that instructs the L<MongoDB::Collection>
query method to sort the results on specified key in descending order.

    $search->desc_sort('first_name', 'last_name');

=head2 limit

The limit method adds a criterion that instructs the L<MongoDB::Collection>
query method to limit the results by the number specified.

    $search->limit(25);

=head2 near

The near method adds a criterion to find locations that are near the supplied
coordinates. This performs a MongoDB $near selection and requires a 2d index to
be on the provided field.

    $search->near(location => [52.30, 13.25]);
    
    ... { "location" : { "$near" : [52.30, 13.25] } }

=head2 never

The never method adds a criterion that instructs the L<MongoDB::Collection>
query method to select all columns except the ones specified. The opposite of
this is the only() method, these two methods can't be used together.

    $search->never('password');

=head2 not_in

The not_in method adds a criterion that specifies a set of expressions that
cannot match in order to return results. The underlying MongoDB expression is
$nin.

    $search->not_in(last_name => ['Teller', 'Penn']);
    
    ... { "last_name" : { "$nin" : ['Teller', 'Penn'] } }

=head2 only

The only method adds a criterion that instructs the L<MongoDB::Collection>
query method to only select the specified columns. The opposite of
this is the never() method, these two methods can't be used together.

    $search->only('first_name', 'last_name', 'login');

=head2 or_where

The or_where method wraps and appends the where criterion.

    $search->or_where('age$gte' => 21);
    $search->or_where('age$lte' => 60);
    
    ... { "$or" : [{ "age" : { "$gte" : 21 }, "age" : { "$lte" : 60 } }] }

=head2 page

The page method is a purely a convenience method which adds a limit and skip
criterion to the query.

    $search->page($limit, $page); # page is optional, defaults to 0

=head2 query

The query method analyzes the current query criteria object and queries the
databases returning a L<MongoDB::Cursor>.

    my $cursor = $search->query;

=head2 skip

The skip method adds a criterion that instructs the L<MongoDB::Collection>
query method to limit the results by the number specified.

    $search->skip(2);

=head2 sort

The sort method adds a criterion that instructs the L<MongoDB::Collection>
query method to sort the results on specified key in the specified order.

    $search->sort(first_name => 1, last_name => -1);

=head2 where

The where method wraps and appends the where criterion.

    $search->where('age$gte' => 21);
    $search->where('age$lte' => 60);
    
    ... { "age" : { "$gte" : 21 }, "age" : { "$lte" : 60 } }

=head2 where_exists

The where_exists method adds a criterion that specifies fields that must exist
in order to return results. The corresponding MongoDB operation is $exists.

    $search->where_exists('mother.name', 'father.name');
    
    ... {
        "mother.name" : { "$exists" : true },
        "father.name" : { "$exists" : true }
    }

=head2 where_not_exists

The where_not_exists method adds a criterion that specifies fields that must NOT
exist in order to return results. The corresponding MongoDB operation is $exists.

    $search->where_not_exists('mother.name', 'father.name');
    
    ... {
        "mother.name" : { "$exists" : false },
        "father.name" : { "$exists" : false }
    }

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

