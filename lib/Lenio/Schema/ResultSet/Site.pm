package Lenio::Schema::ResultSet::Site;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

sub ordered_org
{   shift->search({},{
        prefetch => 'org',
        order_by => 'org.name',
    });
}

1;
