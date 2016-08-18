package Lenio::Schema::ResultSet::Notice;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

sub all_with_count
{   my $self = shift;
    $self->search({}, {
        prefetch  => 'login_notices',
        group_by  => 'me.id',
        '+select' => {
            count => 'login_notices.login_id',
        },
        '+as'     => 'login_count',
    })->all;
}

1;
