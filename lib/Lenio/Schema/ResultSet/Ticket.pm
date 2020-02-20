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
    $search->{'me.task_id'}          = $args{task_id} if defined $args{task_id};

    panic "Need site_id when using fy argument"
        if $args{fy} && !$args{site_id};

    if ($args{uncompleted_only})
    {
        $search->{'me.completed'} = undef;
    }
    if ($args{completed_only})
    {
        $search->{'me.completed'} = { '!=' => undef };
    }
    if ($args{cost_only})
    {
        $search->{'me.cost_actual'} = { '>' => 0 };
    }

    if (!$args{task_id})
    {
        if (defined $args{task_tickets})
        {
            $search->{'me.task_id'} = $args{task_tickets}
                ? { '!=' => undef }
                : undef;
        }
        if (defined $args{with_site_tickets})
        {
            $search->{'me.actionee'} = $args{with_site_tickets}
                ? 'with_site'
                : { '!=' => 'with_site' };
        }
    }

    if ($args{need_invoice_report})
    {
        $search->{'-or'} = [
            report_received => 0,
            invoice_sent    => 0,
        ]
    }

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
        : $args{sort} eq 'type'
        ? ['tasktype.name', 'me.completed']
        : 'me.id';
    $order_by = { -desc => $order_by} if $args{sort_desc};
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
        order_by => $order_by,
    })->all;
}

sub finsum
{   my ($self, %params) = @_;

    my $site = $params{site};

    my $pdf = CtrlO::PDF->new(
        logo         => $params{logo},
        logo_scaling => 0.25,
        orientation  => "portrait", # Default
        top_padding  => 50,
        #footer      => "My PDF document footer",
    );

    # Add a page
    $pdf->add_page;
    # For the first page, move the cursor back up the page to remove the top_padding
    $pdf->move_y_position(50);

    # Add headings
    $pdf->heading($params{company});
    $pdf->heading('Financial Summary', bottommargin => 20);
    my $org = $site->org;
    $pdf->text($org->full_address);

    my @tickets = $self->summary(
        site_id        => $site->id,
        fy             => $params{fy},
        cost_only      => 1,
        completed_only => 1,
        sort           => 'type',
    );
    my @tables; my @data; my $last_tasktype; my $subtotal = 0;

    foreach my $ticket (@tickets)
    {
        my $tasktype = $ticket->task ? $ticket->task->tasktype_name : 'Reactive maintenance';
        if (defined $last_tasktype && $tasktype ne $last_tasktype)
        {
            push @tables, {
                name => $last_tasktype,
                data => [@data], # Copy
                total => $subtotal,
            };
            $subtotal = 0;
            @data = ();
        }

        push @data, [
            $ticket->name,
            $ticket->completed ? $ticket->completed->strftime($params{dateformat}) : '',
            defined $ticket->cost_actual ? '£'.$ticket->cost_actual : '',
            $ticket->contractor ? $ticket->contractor->name : '',
            $ticket->description,
        ];

        $subtotal += ($ticket->cost_actual || 0);

        $last_tasktype = $tasktype;
    }

    push @tables, {
        name => $last_tasktype,
        data => [@data], # Copy
        total => $subtotal,
    };

    my $hdr_props = {
        repeat     => 1,
        font_size  => 8,
    };

    my $total = 0;
    foreach my $table (@tables)
    {
        $pdf->heading($table->{name}, size => 12, topmargin => 10, bottommargin => 0);
        my $data = $table->{data};
        unshift @$data, [
            'Item',
            'Date',
            'Cost',
            'Contractor',
            'Notes',
        ];
        $pdf->table(
            data         => $data,
            header_props => $hdr_props,
            font_size    => 8,
        );
        $pdf->heading("Total cost: £".$table->{total}, indent => 350, size => 10);
        $total += $table->{total};
    }

    $pdf->heading("Total costs: £$total +VAT", size => 14);

    $pdf;
}

1;
