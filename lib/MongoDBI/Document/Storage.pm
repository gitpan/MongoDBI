# ABSTRACT: MongoDBI Document Storage Interface

use strict;
use warnings;

package MongoDBI::Document::Storage;
{
  $MongoDBI::Document::Storage::VERSION = '0.0.3';
}

use 5.001000;

our $VERSION = '0.0.3'; # VERSION

use Moose::Role; # is trait

use MongoDB::Connection;



sub connect {
    
    my ($self, %args) = @_;
    
    my $cfg = $self->config;
    
    # ensure a database and collection are set
    $cfg->set_database unless values %{$cfg->database};
    $cfg->set_collection unless values %{$cfg->collection};
    
    while (my($attr, $value) = each(%{$cfg->database})) {
        $args{$attr} ||= $value;
    }
    
    $args{db_name} = delete $args{name};
    
    die "Please specify the name of the database" unless $args{db_name};
    
    my $database_name   = $args{'db_name'};
    my $collection_name = $cfg->collection->{'name'} ;
    
    my $con  = MongoDB::Connection->new(%args);
    my $db   = $con->get_database( $database_name );
    my $col  = $db->get_collection( $collection_name );
    
    $cfg->_mongo_collection($col);
    $cfg->_mongo_connection($con);
    
    $cfg->database->{connected}++;
    
    # apply index instructions
    foreach my $spec (@{$cfg->indexes}) {
        # spell-it-out so the references aren't altered
        $col->ensure_index({%{$spec->[0]}},{%{$spec->[1]}});
    }
    
    return $self;
    
}


sub disconnect {
    
    my ($self) = @_;
    
    my $cfg = $self->config;
    
    $cfg->_mongo_connection(undef);
    
    $cfg->database->{connected} = 0;
    
    return $self;
    
}

no Moose::Role;

1;
__END__
=pod

=head1 NAME

MongoDBI::Document::Storage - MongoDBI Document Storage Interface

=head1 VERSION

version 0.0.3

=head1 SYNOPSIS

    package main;

    my $cds = CDDB::Album;
    
    ...
    
    $cds->connect(username => '...', password => '....');
    
    1;

=head1 DESCRIPTION

MongoDBI::Document::Storage is a role that provides database-specific
functionality to your MongoDBI document classes.

=head1 METHODS

=head2 connect

The connect method is responsible for establishing the document class's
connection to the MongoDB database. This methods accepts all valid
arguments accepted by L<MongoDB::Connection>.

It is important to note that if no collection name exists when the connect
method is called ... an attempt to auto generate one for you will be made. Also,
it is likely that your connection will fail unless a database name is set.

    package main;

    my $cds = CDDB::Album;
    
    $cds->config->set_database('test');
    
    $cds->connect(username => '...', password => '....');
    
    1;

=head2 disconnect

The disconnect method doesn't actually disconnect you from the database server,
it merely nullifies the MongoDB::Connection object set in your document classes
configuration. This method can be used to switch between and perform operations
across database hosts/connections.

    package main;

    my $cds = CDDB::Album;
    
    $cds->config->set_database('test');
    
    $cds->connect(username => '...', password => '....');
    
    ...
    
    $cds->disconnect;
    
    1;

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

