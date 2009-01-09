package Kiddman::Client::Types;
use Moose;
use Moose::Util::TypeConstraints;

use MooseX::Types
    -declare => [qw(
        LongStr
    )];

use MooseX::Types::Moose 'Str';

enum 'Inputs' => qw(text select checkbox);

subtype LongStr, as Str;

1;