package Lenio::Schema::ResultSet::Login;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

sub active_rs
{   shift->search({
        'me.deleted' => undef,
    }, {
        order_by => [
            'me.surname', 'me.firstname',
        ],
    });
}

sub active
{   shift->active_rs->all;
}

1;
