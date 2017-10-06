package Lenio::Schema::ResultSet::Ticket;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use Log::Report;

sub summary
{   my ($self, %args) = @_;
    my $search = {};

    $search->{'me.site_id'}          = $args{site_id} if $args{site_id};
    $search->{'login_orgs.login_id'} = $args{login}->id unless $args{login}->is_admin;
    $search->{'me.task_id'}          = $args{task_id} if defined $args{task_id};

    panic "Need site_id when using fy argument"
        if $args{fy} && !$args{site_id};

    if ($args{uncompleted_only})
    {
        $search->{'me.completed'} = undef;
    }

    if (!$args{task_id})
    {
        if (defined $args{task_tickets})
        {
            $search->{'me.task_id'} = $args{task_tickets}
                ? { '!=' => undef }
                : undef;
        }
    }

    if ($args{need_invoice_report})
    {
        $search->{'-or'} = [
            report_received => 0,
            invoice_sent    => 0,
        ]
    }

    # Don't show local tickets for admin
    if ($args{login}->is_admin)
    {
        $search->{'task.global'} = [undef, 1];
        $search->{'me.local_only'}    = 0;
    }

    if ($args{fy} || ($args{from} && $args{to}))
    {
        # Work out date to take costs from (ie the financial year)
        my $dtf  = $self->result_source->schema->storage->datetime_parser;
        my $fy   = $args{fy} && Lenio::FY->new(
            site_id => $args{site_id},
            year    => $args{fy},
            schema  => $self->result_source->schema,
        );
        my $from = $args{fy} ? $fy->costfrom : $args{from};
        my $to   = $args{fy} ? $fy->costto   : $args{to};
        my $completed = {
            completed => {
                -between => [
                    $dtf->format_datetime($from),
                    $dtf->format_datetime($to),
                ],
            },
        };
        my $planned = {
            planned   => {
                -between => [
                    $dtf->format_datetime($from),
                    $dtf->format_datetime($to),
                ],
            },
        };
        $planned->{completed} = undef; # XXX if $args{fy}; # Don't include planned tasks completed in another year
        $search->{'-or'} = [$completed, $planned];
    }

    $args{sort} ||= '';
    my $order_by = $args{sort} eq 'title'
        ? 'me.name'
        : $args{sort} eq 'site'
        ? 'site.name'
        : $args{sort} eq 'planned'
        ? 'me.planned'
        : $args{sort} eq 'completed'
        ? 'me.completed'
        : $args{sort} eq 'report'
        ? 'me.report_received'
        : $args{sort} eq 'invoice'
        ? 'me.invoice_sent'
        : 'me.id';
    $order_by = { -desc => $order_by} if $args{sort_desc};
    $self->search($search, {
        prefetch => [
            'task',
            {
                'site' => {
                    'org' => 'login_orgs'
                },
            }
        ],
        order_by => $order_by,
    })->all;
}

1;
