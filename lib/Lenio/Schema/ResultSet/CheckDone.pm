package Lenio::Schema::ResultSet::CheckDone;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

sub summary
{   my ($self, %options) = @_;

    my $dtf  = $self->result_source->schema->storage->datetime_parser;

    $self->search({
        site_id  => $options{site_id},
        datetime => {
            '>=', $dtf->format_datetime($options{from}),
            '<=', $dtf->format_datetime($options{to}),
        },
    }, {
        prefetch => [ {'site_task' => 'task'}, 'check_items_done'],
        order_by => [qw/me.site_task_id me.datetime/],
    })->all;
}

1;
