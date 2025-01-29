package Lenio::Schema::ResultSet::Ticket;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use utf8;

use Log::Report;

sub summary
{   my ($self, %args) = @_;
    my $search = {};

    $search->{'me.site_id'}          = $args{site_id} if $args{site_id};
    $search->{'login_orgs.login_id'} = $args{login}->id if $args{login} && !$args{login}->is_admin;
    $search->{'me.task_id'}          = $args{task_id} if $args{task_id};
    $search->{'me.contractor_id'}    = $args{contractor_ids} if $args{contractor_ids} && @{$args{contractor_ids}};

    panic "Need site_id when using fy argument"
        if $args{fy} && !$args{site_id};

    my $filter = $args{filter};

    my @filters;

    if (my $type = $filter->{type})
    {
        my @type;
        if ($type->{reactive})
        {
            push @type, {'me.task_id' => undef};
        }
        if ($type->{task})
        {
            push @type, {'me.task_id' => { '!=' => undef } };
        }
        push @filters, {
            -or => \@type,
        } if @type;
    }

    if (my $status = $filter->{status})
    {
        my @status;
        if ($status->{not_planned})
        {
            push @status, {'me.planned' => undef, 'me.completed' => undef};
        }
        if ($status->{planned})
        {
            push @status, {'me.planned' => { '!=' => undef }, 'me.completed' => undef };
        }
        if ($status->{completed})
        {
            push @status, {'me.completed' => { '!=' => undef } };
        }
        if ($status->{cancelled})
        {
            push @status, {'me.cancelled' => { '!=' => undef } };
        }
        if (@status)
        {
            push @filters, {
                -or => \@status,
            };
        }
        else {
            # Default to excluding cancelled and completed tickets
            push @filters, {'me.cancelled' => undef, 'me.completed' => undef};
        }
    }
    else {
        # Default to excluding cancelled tickets
        push @filters, {'me.cancelled' => undef, 'me.completed' => undef};
    }

    if (my $actionee = $filter->{actionee})
    {
        my @actionee;
        if ($actionee->{admin})
        {
            push @actionee, {'me.actionee' => 'admin'};
        }
        if ($actionee->{local_action})
        {
            push @actionee, {'me.actionee' => 'with_site'};
        }
        if ($actionee->{local_site})
        {
            push @actionee, {'me.actionee' => 'local'};
        }
        if ($actionee->{contractor})
        {
            push @actionee, {'me.actionee' => 'external'};
        }
        push @filters, {
            -or => \@actionee,
        } if @actionee;
    }

    if (my $costs = $filter->{costs})
    {
        my @costs;
        if ($costs->{actual})
        {
            push @costs, {'me.cost_actual' => { '!=' => undef }};
        }
        if ($costs->{planned})
        {
            push @costs, {'me.cost_planned' => { '!=' => undef }};
        }
        push @filters, {
            -or => \@costs,
        } if @costs;
    }

    if (my $dates = $filter->{dates})
    {
        my $dtf = $self->result_source->schema->storage->datetime_parser;
        my @dates;
        if ($dates->{this_month})
        {
            my $from = DateTime->now->truncate(to => 'month');
            my $to   = $from->clone->add(months => 1);
            push @dates, {
                -and => [
                    'me.provisional' => { '>=' => $dtf->format_date($from) },
                    'me.provisional' => { '<' => $dtf->format_date($to) },
                ]
            };
            push @dates, {
                -and => [
                    'me.planned' => { '>=' => $dtf->format_date($from) },
                    'me.planned' => { '<' => $dtf->format_date($to) },
                ]
            };
            push @dates, {
                -and => [
                    'me.completed' => { '>=' => $dtf->format_date($from) },
                    'me.completed' => { '<' => $dtf->format_date($to) },
                ]
            };
        }
        if ($dates->{next_month})
        {
            my $from = DateTime->now->add(months => 1)->truncate(to => 'month');
            my $to   = $from->clone->add(months => 1);
            push @dates, {
                -and => [
                    'me.provisional' => { '>=' => $dtf->format_date($from) },
                    'me.provisional' => { '<' => $dtf->format_date($to) },
                ]
            };
            push @dates, {
                -and => [
                    'me.planned' => { '>=' => $dtf->format_date($from) },
                    'me.planned' => { '<' => $dtf->format_date($to) },
                ]
            };
            push @dates, {
                -and => [
                    'me.completed' => { '>=' => $dtf->format_date($from) },
                    'me.completed' => { '<' => $dtf->format_date($to) },
                ]
            };
        }
        if ($dates->{this_fy})
        {
            # Although FY is different by site, assume it's from 1st April.
            # This is so that we can filter across multiple sites.
            my $now  = DateTime->now;
            my $year = $now->month >= 4 ? $now->year : $now->year - 1;
            my $from = DateTime->new(
                year  => $year,
                month => 4,
                day   => 1,
            );
            my $to   = $from->clone->add(years => 1);
            push @dates, {
                -and => [
                    'me.provisional' => { '>=' => $dtf->format_date($from) },
                    'me.provisional' => { '<' => $dtf->format_date($to) },
                ]
            };
            push @dates, {
                -and => [
                    'me.planned' => { '>=' => $dtf->format_date($from) },
                    'me.planned' => { '<' => $dtf->format_date($to) },
                ]
            };
            push @dates, {
                -and => [
                    'me.completed' => { '>=' => $dtf->format_date($from) },
                    'me.completed' => { '<' => $dtf->format_date($to) },
                ]
            };
        }
        if ($dates->{blank})
        {
            push @dates, {
                -and => [
                    'me.provisional' => undef,
                    'me.provisional' => undef,
                    'me.planned' => undef,
                    'me.planned' => undef,
                    'me.completed' => undef,
                    'me.completed' => undef,
                ]
            };
        }
        push @filters, {
            -or => \@dates,
        } if @dates;
    }

    if (my $ir = $filter->{ir})
    {
        my @ir;
        if ($ir->{no_invoice})
        {
            push @ir, {'invoice.id' => undef};
        }
        if ($ir->{no_invoice_sent})
        {
            push @ir, {'me.invoice_sent' => 0};
        }
        if ($ir->{no_report})
        {
            push @ir, {'me.report_received' => 0};
        }
        push @filters, {
            -or => \@ir,
        } if @ir;
    }

    $search->{'-and'} = \@filters
        if @filters;

    # Don't show local tickets for admin or financial summary
    if (!$args{login} || $args{login}->is_admin)
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
            completed => [
                -and =>
                    { '>=' => $dtf->format_datetime($from) },
                    { '<'  => $dtf->format_datetime($to) },
            ],
        };
        my $planned = {
            planned => [
                -and =>
                    { '>=' => $dtf->format_datetime($from) },
                    { '<'  => $dtf->format_datetime($to) },
            ],
        };
        $planned->{completed} = undef; # XXX if $args{fy}; # Don't include planned tasks completed in another year
        my $provisional = {
            provisional => [
                -and =>
                    { '>=' => $dtf->format_datetime($from) },
                    { '<'  => $dtf->format_datetime($to) },
            ],
            completed => undef,
            planned   => undef,
        };
        $search->{'-or'} = [$completed, $planned, $provisional];
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
        : $args{sort} eq 'type'
        ? ['tasktype.name', 'me.completed']
        : 'me.id';
    if ($args{sort_desc} || !$args{sort}) # Sort descending for default with ID
    {
        $order_by = { -desc => $order_by};
    }

    $self->search($search, {
        prefetch => [
            {
                task => 'tasktype'
            },
            {
                'site' => {
                    'org' => 'login_orgs'
                },
            }
        ],
        join => 'invoice',
        order_by => $order_by,
    })->all;
}

1;
