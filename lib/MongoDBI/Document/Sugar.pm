# ABSTRACT: Syntactic Sugar For Defining MongoDBI Document Classes

use strict;
use warnings;

package MongoDBI::Document::Sugar;
{
    $MongoDBI::Document::Sugar::VERSION = '0.0.1';
}

use 5.001000;

our $VERSION = '0.0.1';    # VERSION

use Moose::Role;

use DateTime;
use Scalar::Util qw(blessed);
use Carp qw(confess);

use Moose::Exporter;

use MongoDBI::Document::Child;
use MongoDBI::Document::Relative;
use MongoDBI::Document::GridFile;

Moose::Exporter->setup_import_methods(

    with_meta => [
        qw(
          belongs_to
          chain
          config
          embed
          file
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
          )
      ]

);

sub belongs_to {

    return &has_one(@_)

}

sub chain {

    my ($meta, $name, $code) = @_;

    my $config = find_or_create_cfg_attribute($meta);

    confess("config attribute not present") unless blessed($config);

    # create a method on the class that returns a stored criterion query
    $meta->add_method(
        $name => sub {
            my $self = shift;
            return $code->($self->search);
        }
    );

    return $meta;

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

    return undef unless ($name);

    $args{type} ||= 'single';

    my $fields = $config->fields;
    $fields->{$name} = {
        %args,
        is  => 'rw',
        isa => 'MongoDBI::Document::Child'
    };

    # lazy load class
    my $class_file = $args{class};
    $class_file =~ s/::/\//g;
    eval "require $args{class}" unless $INC{"$class_file.pm"};

    my $relative = $meta->add_attribute(
        $name,
        'is'      => 'rw',
        'isa'     => 'MongoDBI::Document::Child',
        'lazy'    => 1,
        'default' => sub {

            MongoDBI::Document::Child->new(
                parent => $meta->{package},
                target => $args{class},
                config => {%args}
              )

        }
    );

    return $relative;

}

sub file {

    my ($meta, $name, %args) = @_;

    my $config = find_or_create_cfg_attribute($meta);

    confess("config attribute not present") unless blessed($config);

    return undef unless ($name);

    $args{type} ||= 'single';

    my $fields = $config->fields;
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
                config => {%args}
              )

        }
    );

    return $gridfile;

}

sub find_or_create_cfg_attribute {

    my $meta = shift;

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
            next
              if $attribute->associated_class->{package} eq $meta->{package};

            my $name   = $attribute->name;
            my $parent = $attribute->associated_class->{package};
            my $fields = $parent->config->fields;

            $config->fields->{$name} = $fields->{$name};
            $config->indexes($parent->config->indexes);    # redundant, fix me

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

    return undef unless ($name);

    $args{type} = 'multiple';

    my $fields = $config->fields;
    $fields->{$name} = {
        %args,
        is  => 'rw',
        isa => 'MongoDBI::Document::Relative'
    };

    # lazy load class
    my $class_file = $args{class};
    $class_file =~ s/::/\//g;
    eval "require $args{class}" unless $INC{"$class_file.pm"};

    my $relative = $meta->add_attribute(
        $name,
        'is'      => 'rw',
        'isa'     => 'MongoDBI::Document::Relative',
        'lazy'    => 1,
        'default' => sub {

            MongoDBI::Document::Relative->new(
                parent => $meta->{package},
                target => $args{class},
                config => {%args}
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

    return undef unless ($name);

    $args{type} = 'single';

    my $fields = $config->fields;
    $fields->{$name} = {
        %args,
        is  => 'rw',
        isa => 'MongoDBI::Document::Relative'
    };

    # lazy load class
    my $class_file = $args{class};
    $class_file =~ s/::/\//g;
    eval "require $args{class}" unless $INC{"$class_file.pm"};

    my $relative = $meta->add_attribute(
        $name,
        'is'      => 'rw',
        'isa'     => 'MongoDBI::Document::Relative',
        'lazy'    => 1,
        'default' => sub {

            MongoDBI::Document::Relative->new(
                parent => $meta->{package},
                target => $args{class},
                config => {%args}
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

    push @{$config->indexes}, [{%args}, {%opts}];

    return $meta;

}

sub is_any {

    my $meta   = shift;
    my %params = @_;
    $params{is}  ||= 'rw';
    $params{isa} ||= 'Any';

    return %params;

}

sub is_array {

    my $meta   = shift;
    my %params = @_;
    $params{is}  ||= 'rw';
    $params{isa} ||= 'ArrayRef';

    return %params;

}

sub is_bool {

    my $meta   = shift;
    my %params = @_;
    $params{is}  ||= 'rw';
    $params{isa} ||= 'Bool';

    return %params;

}

sub is_date {

    my $meta   = shift;
    my %params = @_;
    $params{is}  ||= 'rw';
    $params{isa} ||= 'DateTime';

    return %params;

}

sub is_hash {

    my $meta   = shift;
    my %params = @_;
    $params{is}  ||= 'rw';
    $params{isa} ||= 'HashRef';

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

    my $meta = shift;
    my %params = (extra => {is_key => 1});

    return %params;

}

sub key {

    my ($meta, $name, %data) = @_;

    my $config = find_or_create_cfg_attribute($meta);

    # attribute defaults
    $data{is}  ||= 'rw';
    $data{isa} ||= 'Str';

    confess("config attribute not present") unless blessed($config);

    return undef unless ($name);

    my $fields = $config->fields;
    $fields->{$name} = {%data};

    if ($data{extra}) {

        # handle is_unique index declaration
        if ($data{extra}->{is_key}) {
            &index($meta, $name => 1, unique => 1, drop_dups => 1);
        }

        delete $data{extra};
    }

    # keep track of dirty values
    $data{trigger} = sub {
        my ($self, $new_value, $old_value) = @_;
        push @{$self->_dirty->{$name}},
          { new_value => $new_value,
            old_value => $old_value
          };
    };

    $meta->add_attribute($name, %data);    # add attribute to caller

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

version 0.0.1

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

