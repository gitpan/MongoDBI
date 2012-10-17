use Test::More;

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib $FindBin::Bin . "/lib";
    use lib $FindBin::Bin . "/../lib";
    
    plan $ENV{TEST_MONGODBI}
    ? ( tests => 24 )
    : ( skip_all => 'TEST_MONGODBI is not set. Tests skipped.' );
}

package main;

use CDDB;
use DateTime;

# begin ...

my $app = CDDB->new;

ok "MongoDB::Connection" eq ref $app->config->{connection},
  'app connected to mongodb db';

# build an album (then save it)

my $cds = $app->class('Album');

my $cd = $cds->new( title => 'Thriller', released => DateTime->now );

my $band = $cd->band->add( fullname => 'Michael Jackson', handle => 'M.J.' );

my $track1 = $cd->tracks->add( title => 'Beat It' );

my $track2 = $cd->tracks->add( title => 'Billie Jean' );

   $track1->artists->add($band); # track 1 artist is same as cd artist
   $track2->artists->add($band); # track 2 artist is same as cd artist

# save this album and the related documents

ok $cd->insert, 'first album created successfully';

# ensure the data has been written to the database as intended
{
    
    my $con = $app->config->{connection}; # for checking the ODM's accuracy
    
    # check the albums collection
    
    my $col = $con->get_database('mongodbi_cddb')->get_collection('albums');
    
    my $album = $col->find_one({});
    
    ok ref $album, "album stored and retrieved from mongo";
    
    ok ref $album->{_id}, "album id ok";
    
    ok $album->{title} eq 'Thriller', "album title ok";
    ok "DateTime" eq ref $album->{released}, "album release date ok";
    ok $album->{rating} == 1, "album rating ok, set with default value";
    
    ok "HASH" eq ref $album->{band}
    && values %{$album->{band}}, "album has one band, is set";
    
    ok ref $album->{band}->{'$id'}
    && "artists" eq $album->{band}->{'$ref'},
    
        'album band is a reference to the artists collection' ;
    
    ok "ARRAY" eq ref $album->{tracks}
    && @{$album->{tracks}}, "album has many tracks, is set";
    
    ok @{$album->{tracks}} == 2, "has 2 tracks set";
    
    ok $album->{tracks}->[0]->{title}, 'album track 1 title set ok';
    ok $album->{tracks}->[1]->{title}, 'album track 2 title set ok';
    
    ok "ARRAY" eq ref $album->{tracks}->[0]->{artists},
    
        'album track 1 has many artists' ;
        
    ok "ARRAY" eq ref $album->{tracks}->[1]->{artists},
    
        'album track 2 has many artists' ;
        
    ok @{$album->{tracks}->[0]->{artists}} == 1,
    
        'album track 1 has 1 artist set' ;
        
    ok @{$album->{tracks}->[1]->{artists}} == 1,
    
        'album track 2 has 1 artist set' ;
    
    ok ref $album->{tracks}->[0]->{artists}->[0]->{'$id'}
    && "artists" eq $album->{tracks}->[0]->{artists}->[0]->{'$ref'},
    
        'album track 1 artist set as a reference to the artists collection' ;
        
    ok ref $album->{tracks}->[1]->{artists}->[0]->{'$id'}
    && "artists" eq $album->{tracks}->[1]->{artists}->[0]->{'$ref'},
    
        'album track 2 artist set as a reference to the artists collection' ;

    # check artists collection
    
    $col = $con->get_database('mongodbi_cddb')->get_collection('artists');
    
    my $artist = $col->find_one({});
    
    ok ref $artist->{_id}, "artist id ok";
    ok $artist->{fullname}, "artist fullname ok";
    ok $artist->{handle}, "artist handle ok";
    
    # ensure index was automatically set on artists
    
    my @indexes = $col->get_indexes;
    
    ok grep( { $_->{key}->{fullname} } @indexes),
    
        'artist fullname index was set ok';
    
}

# destroy, kill, end of days

ok $app->config->{connection}->get_database('mongodbi_cddb')->drop, 'dropping database mongodbi_cddb' ;
