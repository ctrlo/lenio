package Lenio::Schema::ResultSet::CheckDone;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use Lenio::CSV;

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

sub summary_csv
{   my ($self, %options) = @_;
    my $dateformat = $options{dateformat};
    my $csv = Lenio::CSV->new;
    my @headings = qw/name frequency date status comments/;
    $csv->combine(@headings);
    my $csvout = $csv->string."\n";
    foreach my $check_done ($self->summary(%options))
    {
        my $check = $check_done->site_task->task;
        my $period = $check->period_qty." ".$check->period_unit.($check->period_qty > 1 ? 's' : '');
        my @row = (
            $check->name,
            $period,
            $check_done->datetime->strftime($dateformat),
            $check_done->status,
            $check_done->comment,
        );
        $csv->combine(@row);
        $csvout .= $csv->string."\n";
    }
    return $csvout;
}

1;
