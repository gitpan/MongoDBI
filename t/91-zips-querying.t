use Test::More;

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib $FindBin::Bin . '/lib';
    use lib $FindBin::Bin . '/../lib';

    plan $ENV{TEST_MONGODBI}
      ? ( tests => 27 )
      : ( skip_all => 'TEST_MONGODBI is not set. Tests skipped.' );
}

package Zips;

use MongoDBI::Document;

store 'zips';

key 'city', is_str;
key 'zip', is_int, is_unique;
key 'loc', is_hash;
key 'pop', is_int;
key 'state', is_str;
key 'terms', is_array;

index 'loc', '2d'; # geospatial index

filter 'in_tristate_area' => sub {
    my ($filter, $self, $population) = @_;
    
    $filter->any_in('state' => ['PA','NJ','DE'])
};

filter 'in_maryland_area' => sub {
    my ($filter, $self, $population) = @_;
    
    $filter->any_in('state' => ['MD'])
};

filter 'has_population' => sub {
    my ($filter, $self, $population) = @_;
    
    $population ||= 1;
    
    shift->where('pop$gt' => $population)
};

package main;

use JSON;
use DateTime;

my $zips = 'Zips';
   $zips->config->set_database('mongodbi_zips');

# play with model a bit
diag 'testing MongoDBI::Document::Storage::Criterion ...';

my $locale = $zips->first;

ok do {
    'Zips' eq ref $locale
},  'first locale found';

ok do {
    $locale->state() =~ /^[A-Z]{2}$/
},  'locale state set ok';

ok do {
    $locale->city() =~ /^[A-Z]+$/
},  'locale city set ok';

ok do {
    'HASH' eq ref $locale->loc()
},  'locale locaction set ok';

ok do {
    $locale->pop() =~ /^\d+$/
},  'locale population set ok';

# let the chaining/searching begin ...

ok do {
    my $search = $zips->query('in_maryland_area');
    $search->count == 421
},  'found 421 cities in maryland area';

ok do {
    my $i = 0;
    my $search = $zips->search('in_maryland_area')->foreach_doc(sub{ ++$i });
    $search->count == 421 && $i == 421
},  '421 cities in maryland area counted manually via the foreach_doc method';

ok do {
    my $search = $zips->query('in_tristate_area');
    $search->count == 2051
},  'found 2,051 cities in the tri-state area';

ok do {
    my $search = $zips->query('in_tristate_area', 'in_maryland_area');
    $search->count == 2472
},  'found 2,472 cities in the tri-state +maryland area';

ok do {
    my @where  = ('in_tristate_area', 'has_population' => 3000);
    my $search = $zips->query(@where);
    $search->count == 1270
},  'found 1,270 cities in the tri-state with over 3000 residents';

ok do {
    my @where  = ('in_tristate_area', 'has_population' => 2000);
    my $search = $zips->query(@where);
    $search->count == 1490
},  'found 1,490 cities in the tri-state with over 2000 residents';

ok do {
    my @where  = ('in_tristate_area', 'has_population');
    my $search = $zips->query(@where);
    $search->count == 2049
},  'found 2,049 cities in the tri-state with more than 1 residents';

# okay, now systematically ...

ok do {
    my $zip = $zips->find_or_create(
        zip   => 00000,
        pop   => 0,
        state => 'XX',
        city  => 'INTERNET',
        loc   => {
            x => 00,
            y => 00
        }
    );
    
    $zip->terms(['NET','WWW']);
    $zip->save;
    
},  'created ficticious 00000 internet zip-code';

ok do {
    my $search = $zips->search->all_in(terms => ['NET', 'WWW'])->query;
    $search->count == 1
},  'found 1 city using the all_in() method';

ok do {
    my $search = $zips->search->any_in(terms => ['001', 'WWW', '100'])->query;
    $search->count == 1
},  'found 1 city using the any_in() method';

ok do {
    my $search = $zips->search->any_of(state => 'PA', 'NJ')->query;
    $search->count == 1998
},  'found 1,998 city within PA and NJ using the any_of() method';

ok do {
    my $search = $zips->search->asc_sort('zip')->query;
    $search->next->{city} eq 'INTERNET'
},  'found 1 city (INTERNET) searching with the asc_sort("zip") method';

ok do {
    my $search = $zips->search->desc_sort('zip')->query;
    $search->next->{city} eq 'KETCHIKAN'
},  'found 1 city (KETCHIKAN) searching with the desc_sort("zip") method';

ok do {
    my $search = $zips->search->limit(25)->query;
    scalar($search->all) == 25 ? 1 : 0
},  'found 25 cities using the limit(25) method';

ok do {
    my $search = $zips->search->near('loc' => [50,30])->query;
    $search->count == 100 ? 1 : 0
},  'found 100 cities within geographical area using the near(50,30) method';

ok do {
    eval {
        my $zip = $zips->find_or_create(
            zip   => 00001,
            pop   => 0,
            state => 'ZZ',
            city  => 'INTRANET',
            loc   => {
                x => 00.00,
                y => 00.00
            }
        );
    };
    $@ ? 1 : 0
},  'document w/malicious loc args dies with safe mode on (by default)';

$zips->config->options->{safe} = 0;

ok do {
    eval {
        my $zip = $zips->find_or_create(
            zip   => 00001,
            pop   => 0,
            state => 'ZZ',
            city  => 'INTRANET',
            loc   => {
                x => 00.00,
                y => 00.00
            }
        );
    };
    $@ ? 0 : 1
},  'document w/malicious loc args lives with safe mode off';

$zips->config->options->{safe} = 1;

ok do {
    my $search = $zips->search->never('loc')->limit(1)->query;
    ! keys %{$search->next->{loc}} ? 0 : 1
},  'excluded the fetching of the loc tag using the never("loc") method';

ok do {
    my $search = $zips->search->not_in(state => ['PA', 'NJ', 'DE'])->query;
    $search->count == 27417 ? 1 : 0
},  'found 27,417 cities in the US excluding the states PA, NJ, DE using the '.
    'not_in() method';

ok do {
    my $search = $zips->search->only('city')->limit(1)->query;
    keys %{$search->next} == 2 ? 1 : 0 # city +id
},  'only fetching the city tag using the only("city") method';

# reqs MongoDB 2.0

#ok do {
#    my $search = $zips->search
#        ->and_where(zip => '00000')->and_where(zip => '01001')->query;
#    $search->count == 2 ? 1 : 0
#},  'found 2 cities by zip using the and_where(...) method';

# reqs MongoDB 2.0

#ok do {
#    my $search = $zips->search
#        ->or_where(zip => '00000')->or_where(zip => '01001')->query;
#    $search->count == 1 ? 1 : 0
#},  'found 1 cities by zip using the or_where(...) method';

ok do {
    my $search = $zips->search->where_exists('terms')->query;
    $search->count == 1 ? 1 : 0
},  'found 1 cities using the where_exists("terms") method';

ok do {
    my $search = $zips->search->where_not_exists('terms')->query;
    $search->count == 29467 ? 1 : 0
},  'found 29,467 cities using the where_not_exists("terms") method';

