
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "A proper ODM (Object-Document-Mapper) for MongoDB ",
  "AUTHOR" => "Al Newkirk <awncorp\@cpan.org>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "MongoDBI",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "MongoDBI",
  "PREREQ_PM" => {
    "Carp" => 0,
    "DateTime" => 0,
    "IO::File" => 0,
    "JSON" => 0,
    "Module::Find" => 0,
    "MongoDB" => 0,
    "Moose" => 0,
    "MooseX::Traits" => 0,
    "Scalar::Util" => 0,
    "boolean" => 0
  },
  "VERSION" => "0.0.8",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



