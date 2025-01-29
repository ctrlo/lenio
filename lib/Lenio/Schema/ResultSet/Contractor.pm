package Lenio::Schema::ResultSet::Contractor;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

sub active
{   shift->search({
        deleted => undef,
    }, {
        order_by => 'me.name'
    })->all;
}

1;
