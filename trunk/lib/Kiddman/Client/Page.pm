package Kiddman::Client::Page;
use Moose;
use Kiddman::Client::Meta::Attribute::Trait::Labeled;

use Kiddman::Client::Types;

has meta_description => (
    traits => [qw(Labeled)],
    is => 'rw',
    isa => 'LongStr',
    label => "Meta Description"
);
has template => (
    traits => [qw(Labeled)],
    is => 'rw',
    isa => 'Str',
    default => sub { 'page.tt' },
    label => 'Template'
);
has title => (
    traits => [qw(Labeled)],
    is => 'rw',
    isa => 'Str',
    required => 1,
    label => "Title"
);

1;
