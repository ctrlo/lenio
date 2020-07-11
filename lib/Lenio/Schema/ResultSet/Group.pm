package Lenio::Schema::ResultSet::Group;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

sub ordered
{   shift->search({}, { order_by => 'me.name' })->all;
}

1;
