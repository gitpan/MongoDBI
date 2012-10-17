use Test::More;

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib $FindBin::Bin . "/lib";
    use lib $FindBin::Bin . "/../lib";
    
    plan $ENV{TEST_MONGODBI}
    ? ( tests => 11 )
    : ( skip_all => 'TEST_MONGODBI is not set. Tests skipped.' );
}

package main;

use CDDB;
use DateTime;

use MongoDB;
use MongoDB::OID;

# begin ...

my $app = CDDB->new;

ok "MongoDB::Connection" eq ref $app->config->{connection}, 'app connected to mongodb db';

ok(  (grep /CDDB::Node/, $app->classes), "Found our self in ->classes" );

my $owner_id = MongoDB::OID->new;

{
	my $node = CDDB::Node->create( 
		owner => $owner_id,
		content => "Test Node",
	);

	for( 0 .. 10 ) { 
		$node->children->add( CDDB::Node->new( owner => $owner_id, content => "Test child $_" ) ); 
	}

	for( 0..3 ) { 
		$node->children->get(0)->children->add( owner => $owner_id, content => "0 child sub child $_" );
	}

	is( $node->content, "Test Node", "Node content in memory" );
	ok( $node->created, "Node has a created time" );
	ok( $node->updated, "Node has an updated time" );

	ok( $node->save, "Node saved" );
}

{
	my $node = CDDB::Node->find_one( owner => $owner_id );
	ok( $node, "Retrieved node with query" );
	is( $node->content, "Test Node", "Node has correct content" );

	is( $node->children->get(2)->content, "Test child 2" );
	is( $node->children->get(0)->children->get(1)->content, "0 child sub child 1" );
}


#for( CDDB::Node->all ) {
	#CDDB::Node->new( CDDB::Node->expand( %$_ ) )->remove;
#}

# destroy, kill, end of days

ok $app->config->{connection}->get_database('mongodbi_cddb')->drop, 'dropping database mongodbi_cddb' ;

