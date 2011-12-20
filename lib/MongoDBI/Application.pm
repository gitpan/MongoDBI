# ABSTRACT: MongoDBI Application Class and Document Class Controller

use strict;
use warnings;

package MongoDBI::Application;
{
  $MongoDBI::Application::VERSION = '0.0.4';
}

use 5.001000;

our $VERSION = '0.0.4'; # VERSION

use Moose ();
use Moose::Exporter;
use MongoDB::Connection;
use Module::Find;

Moose::Exporter->setup_import_methods(

    with_meta => [qw(
        app
    )],
    
    also      => [qw(
        Moose
    )],
    
);

sub init_meta {
    
    my ($dummy, %opts) = @_;
    
    my $meta = Moose->init_meta(%opts);
    
    Moose::Util::MetaRole::apply_base_class_roles(
        for => $opts{for_class},
    );
    
    $meta->add_attribute(
        _config      => (
            is      => 'rw',
            isa     => 'HashRef'
        )
    );
    
    $meta->add_method(
        class => sub {
                
            my ($self, $name) = @_;
            
            return $self->config->{classes}->{$name};
            
        }
    );
    
    $meta->add_method(
        config => sub {
            
            shift->meta->get_attribute('_config');
        
        }
    );
    
    return Class::MOP::class_of($opts{for_class});
    
}

sub app {
    
    my ($meta, $args) = @_;
    
    my $config = $meta->get_attribute('_config');
    
    # prepare mongodb connection for sharing
    if (values %{$args->{database}}) {
        
        $args->{database}->{db_name} = delete $args->{database}->{name}
            if $args->{database}->{name};
        
        die "Please specify the name of the database"
            unless $args->{database}->{db_name};
        
        $config->{connection} =
            MongoDB::Connection->new(%{$args->{database}});
        
    }
    
    # load specified application classes
    my $class_name = $meta->{package};
    my @class_list = ();
    
    # load children of self
    if ($args->{classes}->{self}) {
        
        push @class_list, useall($class_name);
        
    }
    
    # load additional supporting classes
    if ($args->{classes}->{load}) {
        
        foreach my $class_name (@{$args->{classes}->{load}}) {
            
            my $class_file = $class_name;
               $class_file =~ s/::/\//g;
            
            eval "require $class_name" unless $INC{"$class_file.pm"};
            push @class_list, useall($class_name);
            
        }
        
    }
    
    foreach my $class (@class_list) {
        
        # register class name variations
        my $class_shortname = $class;
           $class_shortname =~ s/^$class_name\:://;
           
        my $class_slang = $class_shortname;
           $class_slang =~ s/([a-z])([A-Z])/$1_$2/g;
           $class_slang =~ s/::/_/g;
           $class_slang = lc $class_slang;
           
           $config->{classes}->{$class} = $class;
           $config->{classes}->{$class_shortname} = $class;
           $config->{classes}->{$class_slang} = $class;
        
        # configure child classes with shared config
        if ($config->{connection}) {
            
            my %db_config = %{$args->{database}};
            
            $db_config{name} = delete $db_config{db_name}
                if $db_config{db_name};
            
            $class->config->set_database(%db_config);
            $class->config->set_collection(%{$args->{collection}});
            
            my $database_name = $class->config->database->{'name'} ;
            my $collection_name = $class->config->collection->{'name'} ;
            
            my $con  = $config->{connection};
            my $db   = $con->get_database( $database_name );
            my $col  = $db->get_collection( $collection_name );
            
            $class->config->_mongo_collection($col);
            $class->config->_mongo_connection($con);
            
            $class->config->database->{connected} = 1;
            
            # apply index instructions
            foreach my $spec (@{$class->config->indexes}) {
                # spell-it-out so the references aren't altered
                $col->ensure_index({%{$spec->[0]}},{%{$spec->[1]}});
            }
            
        }
        
    }
    
}





1;
__END__
=pod

=head1 NAME

MongoDBI::Application - MongoDBI Application Class and Document Class Controller

=head1 VERSION

version 0.0.4

=head1 SYNOPSIS

    package CDDB;

    use MongoDBI;
    
    app {
    
        # shared mongodb connection
        database => {
            name => 'mongodbi_cddb',
            host => 'mongodb://localhost:27017'
        },
    
        # load child doc classes
        classes => {
            self => 1 # loads CDDB::*
        }
    
    };
    
    1;

=head1 DESCRIPTION

MongoDBI::Application is used to load and configure associated document classes.
It is essentially the application hub (or starting-point). Because all MongoDBI
document classes can have their own database configuration, and thus need to be
setup individually, MongoDBI::Application can be used to bring those individual
classes together to form a single application.

MongoDBI::Application exports the app() method which allows you to configure
your application having the configuration applied to all associated document
classes. MongoDBI::Application will also load all associated classes and make
them available through the class() method after instantiation.

Modeling your database schema will involve learning how models are crafted
using L<MongoDBI::Document>, please read that documentation towards getting
started. Enjoy!!!

=head1 EXPORTS

=head2 app

The app method will be exported into the calling class allowing it to configure
all associated document classes. L<MongoDBI::Document> classes are designed so
that each class may use a different database connection for greater flexibility,
however there are times when you will want/need all of your application's
document classes to share a single database connection and MongoDBI::Application
allows you to do that. MongoDBI::Application can also preload specified classes.

The following examples are recognized parameters the app() method uses to
configure your application.

    # share mongodb connection across all document classes
    app {
        
        # shared mongodb connection
        # accepts all parameters MongoDB::Connection does
        database => {
            name => 'mongodbi_cddb',
            host => 'mongodb://localhost:27017'
        }
        
    };
    
    # load desired document classes 
    app {
        
        classes => {
            self => 1, # loads all classes under the current namespace
            load => [
                'Other::Classes',
                'More::Classes',
            ]
        }
        
    };

=head1 ATTRIBUTES

=head2 config

The config attribute gives you access to the MongoDBI::Application class
configuration although it is likely you will never need to used it as the
important elements are all exposed via methods.

    my $app = App->new;
    
    $app->config;

=head1 METHODS

=head2 class

The class method returns the class (string, uninstantiated) for the associated
document class registered by the app() method. The class method accepts a class
short-name and returns the fully-qualified class name.

    my $app = App->new;
    
    # base class name under same namespace not required (e.g. app_*)
    
    my $foo = $app->class('foo'); # returns App::Foo;
    my $bar = $app->class('bar_baz'); # returns App::BarBaz;
    
    # must specify the base class name on foreign classes
    
    my $xyz = $app->class('app2_xyz'); # returns App2::XYZ;
    
    # if you're a stickler for convention,
    # you can also use case-appropriate syntax
    
    my $foo = $app->class('Foo'); # returns App::Foo;
    my $bar = $app->class('BarBaz'); # returns App::BarBaz;

=head1 AUTHOR

Al Newkirk <awncorp@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by awncorp.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

