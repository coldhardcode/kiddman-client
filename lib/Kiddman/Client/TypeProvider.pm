package Kiddman::Client::TypeProvider;
use Moose::Role;

has 'value_accessor' => (
    is => 'ro',
    isa => 'Maybe[Str]',
    default => sub { 'id' }
);

requires 'get_values';

1;