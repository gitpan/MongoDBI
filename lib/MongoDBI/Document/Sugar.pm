# ABSTRACT: Syntactic Sugar For Defining MongoDBI Document Classes

use strict;
use warnings;

package MongoDBI::Document::Sugar;
{
  $MongoDBI::Document::Sugar::VERSION = '0.0.8';
}

use 5.001000;

our $VERSION = '0.0.8'; # VERSION

use Moose::Role;

use DateTime;
use Scalar::Util qw(blessed);
use Carp qw(confess);

use Moose::Exporter;

use MongoDBI::Document::Child;
use MongoDBI::Document::Relative;
use MongoDBI::Document::GridFile;

Moose::Exporter->setup_import_methods(

    with_meta => [qw(
        belongs_to
        config
        embed
        file
        filter
        index
        has_many
        has_one
        is_any
        is_array
        is_bool
        is_date
        is_hash
        is_int
        is_num
        is_req
        is_str
        is_unique
        key
        store
    )]
    
);



sub belongs_to {
    
    return &has_one(@_)
    
}


sub config {
    
    my ($meta) = @_;
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);

    return $config;
    
}


sub embed {
    
    my ($meta, $name, @args) = @_;
    
    my %args = @args == 1 ? (class => $args[0]) : @args;
    
    confess("embed requires a class attribute") unless $args{class};
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);

    return unless ($name);
    
    $args{type} ||= 'single';
    
    my  $fields = $config->fields;
        $fields->{$name} = {
            %args,
            is  => 'rw',
            isa => 'MongoDBI::Document::Child'
        };
    
    # lazy load class
    my $class_file = $args{class}; $class_file =~ s/::/\//g;
    eval { require $args{class} } unless $INC{"$class_file.pm"};
    
    my $relative = $meta->add_attribute(
            $name,
            'is'      => 'rw',
            'isa'     => 'MongoDBI::Document::Child',
            'lazy'    => 1,
            'default' => sub {
                
                MongoDBI::Document::Child->new(
                    parent => $meta->{package},
                    target => $args{class},
                    config => { %args }
                )
                
            }
    );
    
    return $relative;
    
}


sub file {
    
    my ($meta, $name, %args) = @_;
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);

    return unless ($name);
    
    $args{type} ||= 'single';
    
    my  $fields = $config->fields;
        $fields->{$name} = {
            %args,
            is  => 'rw',
            isa => 'MongoDBI::Document::GridFile'
        };
    
    my $gridfile = $meta->add_attribute(
            $name,
            'is'      => 'rw',
            'isa'     => 'MongoDBI::Document::GridFile',
            'lazy'    => 1,
            'default' => sub {
                
                my $package = $meta->{package};
                my $conf    = $package->config;
                my $db_name = $conf->database->{name};
                my $conn    = $conf->_mongo_connection;
                my $grid_fs = $conn->get_database($db_name)->get_gridfs;
                
                MongoDBI::Document::GridFile->new(
                    parent => $package,
                    target => $grid_fs,
                    config => { %args }
                )
                
            }
    );
    
    return $gridfile;
    
}


sub filter {
    
    my ($meta, $name, $code) = @_;
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);
    
    # register a search method that returns a stored criterion
    $config->searches->{$name} = sub {
        return $code->(@_);
    };
    
    return $meta;
    
}

sub find_or_create_cfg_attribute {
    
    my $meta   = shift;
    
    my $config = $meta->get_attribute('_config');
    
    unless ($config) {
        
        # global class configuration object
        $config = $meta->add_attribute(
            '_config',
            'is'      => 'rw',
            'traits'  => ['MongoDBI::Document::Config'],
            'default' => sub { shift->meta->get_attribute('_config') }
        );
        
        # spectacularly inefficient, walk inheritance
        # tree ensure all fields are registered with this class
        foreach my $attribute ($meta->get_all_attributes) {
            
            next if $attribute->name =~ /^_/;
            next if $attribute->associated_class->{package}
                 eq $meta->{package};
            
            my $name   = $attribute->name ;
            my $parent = $attribute->associated_class->{package};
            my $fields = $parent->config->fields;
            
               $config->fields->{$name} = $fields->{$name};
               $config->indexes($parent->config->indexes); # inefficient, fix me
            
        }
        
    }
    
    return $config;
    
}


sub has_many {
    
    my ($meta, $name, @args) = @_;
    
    my %args = @args == 1 ? (class => $args[0]) : @args;
    
    confess("embed requires a class attribute") unless $args{class};
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);

    return unless ($name);
    
    $args{type} = 'multiple';
    
    my  $fields = $config->fields;
        $fields->{$name} = {
            %args,
            is  => 'rw',
            isa => 'MongoDBI::Document::Relative'
        };
    
    # lazy load class
    my $class_file = $args{class}; $class_file =~ s/::/\//g;
    eval { require $args{class} } unless $INC{"$class_file.pm"};
    
    my $relative = $meta->add_attribute(
            $name,
            'is'      => 'rw',
            'isa'     => 'MongoDBI::Document::Relative',
            'lazy'    => 1,
            'default' => sub {
                
                MongoDBI::Document::Relative->new(
                    parent   => $meta->{package},
                    target   => $args{class},
                    config   => {%args}
                )
                
            }
    );
    
    return $relative;
    
}


sub has_one {
    
    my ($meta, $name, @args) = @_;
    
    my %args = @args == 1 ? (class => $args[0]) : @args;
    
    confess("embed requires a class attribute") unless $args{class};
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);

    return unless ($name);
    
    $args{type} = 'single';
    
    my  $fields = $config->fields;
        $fields->{$name} = {
            %args,
            is  => 'rw',
            isa => 'MongoDBI::Document::Relative'
        };
    
    # lazy load class
    my $class_file = $args{class}; $class_file =~ s/::/\//g;
    eval { require $args{class} } unless $INC{"$class_file.pm"};
    
    my $relative = $meta->add_attribute(
            $name,
            'is'      => 'rw',
            'isa'     => 'MongoDBI::Document::Relative',
            'lazy'    => 1,
            'default' => sub {
                
                MongoDBI::Document::Relative->new(
                    parent   => $meta->{package},
                    target   => $args{class},
                    config   => {%args}
                )
                
            }
    );
    
    return $relative;
    
}


sub index {
    
    my ($meta, @args) = @_;
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);
    
    my %args = @args == 1 ? ($args[0] => 1) : @args;
    my %opts = ();
    
    foreach my $option (qw/unique drop_dups safe background name/) {
        $opts{$option} = delete $args{$option} if $args{$option};
    }
    
    push @{$config->indexes}, [{%args},{%opts}];
    
    return $meta;
    
}


sub is_any {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}      ||= 'rw';
       $params{isa}     ||= 'Any';
    
    return %params;
    
}


sub is_array {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}      ||= 'rw';
       $params{isa}     ||= 'ArrayRef';
    
    return %params;
    
}


sub is_bool {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}      ||= 'rw';
       $params{isa}     ||= 'Bool';
    
    return %params;
    
}


sub is_date {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}      ||= 'rw';
       $params{isa}     ||= 'DateTime';
    
    return %params;
    
}


sub is_hash {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}      ||= 'rw';
       $params{isa}     ||= 'HashRef';
    
    return %params;
    
}


sub is_id {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}  ||= 'rw';
       $params{isa} ||= 'MongoDB::OID';
    
    return %params;
    
}


sub is_inc {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}      ||= 'rw';
       $params{isa}     ||= 'Int';
       $params{lazy}    ||= 1;
       $params{default} ||= sub { shift->count + 1 };
    
    return %params;
    
}


sub is_int {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}  ||= 'rw';
       $params{isa} ||= 'Int';
    
    return %params;
    
}


sub is_num {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}  ||= 'rw';
       $params{isa} ||= 'Num';
    
    return %params;
    
}


sub is_req {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}       ||= 'rw';
       $params{required} ||= 1;
    
    return %params;
    
}


sub is_str {
    
    my $meta   = shift;
    my %params = @_;
       $params{is}  ||= 'rw';
       $params{isa} ||= 'Str';
    
    return %params;
    
}


sub is_unique {
    
    my $meta   = shift;
    my %params = (extra => { is_key => 1 });
    
    return %params;
    
}


sub key {
    
    my ($meta, $name, %data) = @_;
    
    my $config = find_or_create_cfg_attribute($meta);
    
    # attribute defaults
    $data{is}  ||= 'rw';  
    $data{isa} ||= 'Str'; 
    
    confess("config attribute not present") unless blessed($config);

    return unless ($name);
    
    my $fields = $config->fields;
       $fields->{$name} = { %data };
       
       if ($data{extra}) {
        
            # handle is_unique index declaration
            if ($data{extra}->{is_key}) {
                &index($meta, $name => 1, unique => 1, drop_dups => 1);
            }
            
            delete $data{extra} ;
       }
    
    # keep track of dirty values
    $data{trigger} = sub {
        my ($self, $new_value, $old_value) = @_;
        push @{$self->_dirty->{$name}}, {
            new_value => $new_value,
            old_value => $old_value
        };
    };
    
    $meta->add_attribute($name, %data); # add attribute to caller
    
    return $meta;
    
}


sub store {
    
    my ($meta, @args) = @_;
    
    my $config = find_or_create_cfg_attribute($meta);
    
    confess("config attribute not present") unless blessed($config);
    
    my %args = @args == 1 ? (name => $args[0]) : @args;
    
    $args{naming} ||= 'same';

    $config->set_collection(%args);
    
    return $meta;
    
}

no Moose::Exporter;

1;
__END__
=pod

=head1 NAME

MongoDBI::Document::Sugar - Syntactic Sugar For Defining MongoDBI Document Classes

=head1 VERSION

version 0.0.8

=head1 SYNOPSIS

    package Child;

    use MongoDBI::Document;
    
    store 'children';
    
    key 'ssn', is_id, is_req; # unique index, auto-incrementing
    key 'full_name', is_str, is_req;
    
    embed 'goals', class => 'Child::Goal', type => 'multiple';
    
    belongs_to 'mom', class => 'Child::Parent';
    
    has_one 'best_friend', class => 'Child::Friend';
    
    has_many 'ideas', class => 'Child::Idea';
    
    1;

=head1 DESCRIPTION

MongoDBI::Document::Sugar provides the DSL (domain-specific-language) used to
define your L<Moose>-based MongoDB document classes. It is important to note
that the underlying structure of your class is provided by Moose and you can
and should capitalize on this in the development of your classes.

=head1 EXPORTS

=head2 belongs_to

The belongs_to keyword is a relationship identifier that creates a 1-1
(one-to-one) relationship between the current class and the class specified by
the required class attribute. This is accomplished by wrapping the class
specified by the class attribute with a L<MongoDBI::Document::Relative>
instance. Please read the documentation at L<MongoDBI::Document::Relative> for
more information on using this object.

    package Child;
    
    use MongoDBI::Document;
    
    belongs_to 'father', class => 'Father';
    belongs_to 'mother', class => 'Mother';
    
    package main;
    
    my $child = Child->new(...);
    
    $child->father->add(...); # see M::D::Relative for more info
    
    # embed can't append an array, this replaces old dad with a new dad
    $child->father->add(...); 
    
    $child->mother->add(...);

=head2 config

The config keyword provides direct access to the configuration object which
includes functionality from L<MongoDBI::Document::Config>. You will most likely
never need to make use of this keyword within your application classes. This
keyword should not be confused with the config method with which you will likely
use to configure your database connection, made available via
L<MongoDBI::Document::Base>.

    package main;
    
    my $config = Child->config; # direct access to the configuration object

=head2 embed

The embed keyword is a relationship identifier that creates a 1<->1
(one-to-one - document-in-document) relationship between the current class and
the class specified by the required class attribute. This is accomplished by
wrapping the class specified by the class attribute with a
L<MongoDBI::Document::Child> instance. Please read the documentation at
L<MongoDBI::Document::Child> for more information on using this object.

The embed keyword can be provided an optional argument ("multiple") that if
true will instruct the relationship management class (M::D::Child) to allow an
array of objects to be created, ... otherwise calling the add method a second
time will simply replace the existing object.

    package Child;
    
    use MongoDBI::Document;
    
    embeds 'room', class => 'Child::Room';
    embeds 'toys', class => 'Child::Toy', multiple => 1;
    
    package main;
    
    my $child = Child->new(...);
    
    $child->room->add(...); # assign a room to the child
    
    $child->toys->add(...);
    $child->toys->add(...);
    $child->toys->add(...); # a child with three toys

=head2 file

The file keyword is a relationship identifier that creates a 1-1
(one-to-one) relationship between the current class and file stored within the 
MongoDB GridFS. This is accomplished by wrapping the specified attribute with a
L<MongoDBI::Document::GridFile> instance. Please read the documentation at
L<MongoDBI::Document::GridFile> for more information on using this object.

The file keyword can be provided an optional argument ("multiple") that if
true will instruct the relationship management class (M::D::GridFile) to allow
an array of file objects to be created, ... otherwise calling the add method a
second time will simply replace the existing file object.

    package Child;
    
    use MongoDBI::Document;
    
    file 'photo';
    
    package main;
    
    my $child = Child->new(...);
    
    $child->photo->add($file_path, ...); # attach a photo to the child record
    
    # file can append an array if multiple arg is set, else replaces
    $child->photo->add($file_path, ...); 

=head2 filter

The filter keyword registers class related filters for quickly composing a
chainable L<MongoDBI::Document::Storage::Criterion> search object which is the
main MongoDBI query abstraction layer. Please see the documentation available
with L<MongoDBI::Document::Storage::Criterion> for more information on querying.

    package Child;
    
    use MongoDBI::Document;
    
    filter 'is_in_school' => sub {
        shift->where('school.name' => qr/./);
    };
    
    filter 'is_under_age' => sub {
        shift->where('age$lt' => 21);
    };
    
    filter 'is_something_special' => sub {
        my ($filter, $self, @args) = @_;
        ...
    };
    
    package main;
    
    # search made simple
    
    my $results = Child->search('is_under_age', 'is_in_school')->query; 
    
    while (my $child = $results->next) {
        ...
    }

=head2 has_many

The has_many keyword is a relationship identifier that creates a 1-*
(one-to-many) relationship between the current class and the class specified by
the required class attribute. This is accomplished by wrapping the class
specified by the class attribute with a L<MongoDBI::Document::Relative>
instance. Please read the documentation at L<MongoDBI::Document::Relative> for
more information on using this object.

    package Child;
    
    use MongoDBI::Document;
    
    has_many 'sisters', class => 'Child::Sibling';
    has_many 'brothers', class => 'Child::Sibling';
    
    package main;
    
    my $child = Child->new(...);
    
    $child->sisters->add(...); # see M::D::Relative for more info
    $child->sisters->add(...); # has_many can append an array
    $child->sisters->add(...); 
    
    $child->brothers->add(...);

=head2 has_one

The has_one keyword is a relationship identifier that creates a 1-1
(one-to-one) relationship between the current class and the class specified by
the required class attribute. This is accomplished by wrapping the class
specified by the class attribute with a L<MongoDBI::Document::Relative>
instance. Please read the documentation at L<MongoDBI::Document::Relative> for
more information on using this object.

    package Child;
    
    use MongoDBI::Document;
    
    has_one 'brain', class => 'Child::Brain';
    
    package main;
    
    my $child = Child->new(...);
    
    $child->brain->add(...); # give the child a brain
    $child->brain->add(...); # replace the child's brain

=head2 index

The index keyword queues-up an index rule to be executed when a connection to
the database is made. The index method will intelligently separate your fields
and option arguments. Please try to avoid using "name" as a field (indexing a
field label "name" will not function properly).

    package Child;
    
    use MongoDBI::Document;
    
    key 'first_name';
    key 'last_name';
    
    index first_name => 1, last_name => -1, unique => 1;
    
    package main;
    
    my $child = Child;
    
    $child->config->set_database('test');
    
    $child->connect; # indexes are now set

=head2 is_any

The is_any keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'first_name', is_any;
    
    # is the equivalent of:
    
    key 'first_name' => (
        is  => 'rw',
        isa => 'Any'
    );
    
    # overwrite the default access attribute
    
    key 'first_name', is_any is => 'ro';

=head2 is_array

The is_array keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'favorite_movies', is_array;
    
    # is the equivalent of:
    
    key 'favorite_movies' => (
        is  => 'rw',
        isa => 'Array'
    );
    
    # overwrite the default access attribute
    
    key 'favorite_movies', is_array is => 'ro';

=head2 is_bool

The is_bool keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'attending_school', is_bool;
    
    # is the equivalent of:
    
    key 'attending_school' => (
        is  => 'rw',
        isa => 'Bool'
    );
    
    # overwrite the default access attribute
    
    key 'attending_school', is_bool is => 'ro';

=head2 is_date

The is_date keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'date_of_birth', is_date;
    
    # is the equivalent of:
    
    key 'date_of_birth' => (
        is  => 'rw',
        isa => 'DateTime'
    );
    
    # overwrite the default access attribute
    
    key 'date_of_birth', is_date is => 'ro';

=head2 is_hash

The is_hash keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'facebook_stream', is_hash;
    
    # is the equivalent of:
    
    key 'facebook_stream' => (
        is  => 'rw',
        isa => 'HashRef'
    );
    
    # overwrite the default access attribute
    
    key 'facebook_stream', is_hash is => 'ro';

=head2 is_id

The is_id keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'student_id', is_id;
    
    # is the equivalent of:
    
    key 'student_id' => (
        is  => 'rw',
        isa => 'MongoDB::OID'
    );
    
    # overwrite the default access attribute
    
    key 'student_id', is_id is => 'ro', default => sub { ... };

=head2 is_inc

The is_inc keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'child_id', is_inc;
    
    # is the equivalent of:
    
    key 'child' => (
        is  => 'rw',
        isa => 'Int',
        default => sub {
            ... # count documents + 1
        }
    );

=head2 is_int

The is_int keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'student_id', is_int;
    
    # is the equivalent of:
    
    key 'student_id' => (
        is  => 'rw',
        isa => 'Int'
    );
    
    # overwrite the default access attribute
    
    key 'student_id', is_int is => 'ro';

=head2 is_num

The is_num keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'school_dues', is_num;
    
    # is the equivalent of:
    
    key 'school_dues' => (
        is  => 'rw',
        isa => 'Num'
    );
    
    # overwrite the default access attribute
    
    key 'school_dues', is_num is => 'ro';

=head2 is_req

The is_req keyword is L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'ssn', is_req;
    
    # is the equivalent of:
    
    key 'ssn' => (
        is  => 'rw',
        isa => 'Str', # unless an additional type shorthand is used
        required => 1
    );
    
    # overwrite the default access attribute
    
    key 'ssn', is_req is => 'ro';
    
    # combine attribute shorthands
    
    key 'ssn', is_req, is_num;

=head2 is_str

The is_str keyword, used by default if no other type shorthand is given, is
L<Moose> attribute shorthand for the following:

    package Child;
    
    use MongoDBI::Document;
    
    key 'nickname', is_str;
    
    # is the equivalent of:
    
    key 'nickname' => (
        is  => 'rw',
        isa => 'Str'
    );
    
    # overwrite the default access attribute
    
    key 'nickname', is_str is => 'ro';

=head2 is_unique

The is_unique keyword simply signals the key keyword to create a unique
ascending index (with drop_dups on) on the associated field. The following is an
example.

    package Child;
    
    use MongoDBI::Document;
    
    key 'ssn', is_num, is_unique;
    
    # is the equivalent of:
    
    key 'ssn' => (
        is  => 'rw',
        isa => 'Num'
    );
    
    index 'ssn' => 1, unique => 1, drop_dups => 1;

=head2 key

The key keyword operates much in the same way the L<Moose> has() method does
with the added behavior of registering the field in the class's configuration
for later use by MongoDBI.

The key and has keywords can be used side-by-side ... with the understanding
that the Moose has() method doesn't register a MongoDBI field so when expanding
and collapsing data (which occurs in practically ever method that interacts
with the database) happens the field/attribute create by the Moose has() method
will not be saved to the database.

The key keyword accepts all key/values pairs that its Moose counterpart does and
the following is an example of that:

    package Child;
    
    use MongoDBI::Document;
    
    key 'first_name', is_req;
    key 'last_name', is_req;
    
    key 'nickname' => (
        is  => 'rw',
        isa => 'Str'
    );
    
    has 'skill_level' => (
        is  => 'rw',
        isa => 'Num'
    );
    
    key 'attitude', is_int, default => 1;

=head2 store

The store keyword sets the MongoDB collection name for the current class, it
accepts the same parameters allowed by the set_collection() method in the
L<MongoDBI::Document::Config> module. The following is an example of that:

    package Child;
    
    use MongoDBI::Document;
    
    # based on default naming conventions the class above will default to a
    # collection name of "childs"
    
    package Child;
    
    use MongoDBI::Document;
    
    store 'children';
    
    # declare naming convention and let set_collection() spell-it-out
    
    package Child;
    
    use MongoDBI::Document;
    
    store name => __PACKAGE__, naming => [
        short, plural, ... 
    ];
    
    # see M::D::Config set_collection() for more naming conventions

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

