use strict;
use Test::More tests => 3;

use_ok('Kiddman::Client::Page');

my $page = Kiddman::Client::Page->new(
	title => 'thingie'
);
isa_ok($page, 'Kiddman::Client::Page');

cmp_ok($page->title, 'eq', 'thingie', 'title set');
cmp_ok($page->meta->get_attribute_map->{'title'}->label, 'eq', 'Title', 'label');