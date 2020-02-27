package Lenio::Schema::ResultSet::Task;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use utf8; # Needed for £ symbols in PDF

use CtrlO::PDF;
use DBIx::Class::Helper::ResultSet::CorrelateRelationship 2.034000;
use Number::Format;
use Lenio::FY;
use Log::Report;
use Text::CSV;

__PACKAGE__->load_components(qw(Helper::ResultSet::DateMethods1 Helper::ResultSet::CorrelateRelationship));

sub last_completed
{   my ($self, %options) = @_;
    delete $options{$_} # Shouldn't exist, delete just in case
        foreach qw/fy from to/;
    # undef filler needed to prevent context otherwise generating skewed hash
    my %completed = map { $_->id => ($_->last_completed||undef) } $self->summary(%options);
    \%completed;
}

sub summary
{   my ($self, %options) = @_;

    my $order_by = [
        'tasktype.name', 'me.name'
    ];
    my $site_id = $options{site_id};
    my $search  = { site_check => 0 };
    $search->{'site_tasks.site_id'} = $site_id if $site_id && $options{onlysite};
    $search->{'site_tasks.site_id'} = undef if $site_id && $options{excluded};
    $search->{'me.global'} = $options{global} if exists $options{global};

    $site_id
        or return $self->search($search, { order_by => $order_by, join => 'tasktype' })->all;

    local $Lenio::Schema::Result::Task::SITEID = $site_id;

    my @dates;

    if ($options{fy} || $options{from} || $options{to})
    {
        # Work out date to take costs from (ie the financial year)
        my $dtf  = $self->result_source->schema->storage->datetime_parser;
        my $fy   = $options{fy} && $site_id && Lenio::FY->new(site_id => $site_id, year => $options{fy}, schema => $self->result_source->schema);
        my $from = $fy ? $fy->costfrom : $options{from};
        my $to   = $fy ? $fy->costto   : $options{to};
        if ($from && $to)
        {
            @dates = (
                completed           => {
                    -between => [
                        $dtf->format_datetime($from),
                        $dtf->format_datetime($to),
                    ],
                },
                -and => [
                    planned             => {
                        -between => [
                            $dtf->format_datetime($from),
                            $dtf->format_datetime($to),
                        ],
                    },
                    completed => undef,
                ],
                -and => [
                    provisional => {
                        -between => [
                            $dtf->format_datetime($from),
                            $dtf->format_datetime($to),
                        ],
                    },
                    completed => undef,
                    planned   => undef,
                ],
            );
        }
        elsif ($from)
        {
            @dates = (
                completed => {
                    '>' => $dtf->format_datetime($from),
                },
                -and => [
                    planned => {
                        '>' => $dtf->format_datetime($from),
                    },
                    completed => undef,
                ],
                -and => [
                    provisional => {
                        '>' => $dtf->format_datetime($from),
                    },
                    completed => undef,
                    planned   => undef,
                ],
            );
        }
        elsif ($to)
        {
            @dates = (
                completed => {
                    '<' => $dtf->format_datetime($to),
                },
                -and => [
                    planned => {
                        '<' => $dtf->format_datetime($to),
                    },
                    completed => undef,
                ],
                -and => [
                    provisional => {
                        '<' => $dtf->format_datetime($to),
                    },
                    completed => undef,
                    planned   => undef,
                ],
            );
        }
        # Also search for tickets without a planned date (in order to
        # add costs), but only if currently viewed dates are this FY year.
        # This is so that tasks can be allocated estimated costs, but without
        # needing a planned date on the ticket that has been raised.
        push @dates, (
            -and => [
                completed   => undef,
                planned     => undef,
                provisional => undef,
            ],
        ) if $fy && (DateTime->compare(DateTime->now, $from) > 0)
           && (DateTime->compare(DateTime->now, $to) < 0);
    }

    my $schema = $self->result_source->schema;
    $self->search($search, {
        order_by => $order_by,
        prefetch => [
            'tasktype',
            {
                site_tasks => 'site'
            },
        ],
        select => [
            'me.id', 'me.name', 'me.description', 'me.period_unit', 'me.period_qty', 'me.global', 'me.site_check',
            'site_tasks.site_id',
            # This next block selects the contractor of the most recent ticket
            # in the relevant selection
            $schema->resultset('Ticket')->search({
                'ticket.id' => {'=' => $schema->resultset('Task')
                    ->correlate('tickets')
                    ->search({ site_id => $site_id, -or => [@dates]})
                    ->get_column('id')
                    ->max_rs->as_query}
            },{
                alias    => 'ticket', # Prevent conflict with other "me" table
                prefetch => 'contractor',
            })->get_column('contractor.name')->max_rs->as_query,
        ],
        as => [qw/
            id name description period_unit period_qty global site_check site_tasks.site_id contractor_name
        /],
        '+columns' => {
            last_completed => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id, -or => [@dates]})
                ->get_column('completed')
                ->max_rs->as_query,
            last_planned => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id, -or => [@dates]})
                ->get_column('planned')
                ->max_rs->as_query,
            next_planned => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id }) # Next regardless of date options
                ->get_column('planned')
                ->max_rs->as_query,
            cost_planned => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id, -or => [@dates]})
                ->get_column('cost_planned')
                ->sum_rs->as_query,
            cost_actual => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id, -or => [@dates]})
                ->get_column('cost_actual')
                ->sum_rs->as_query,
            site_has_task => $schema->resultset('Task')
                ->correlate('site_tasks')
                ->search({ site_id => $site_id })
                ->count_rs->as_query,
       }
    })->all;
}

sub populate_tickets
{   my ($self, %params) = @_;
    my $tickets_rs = $self->result_source->schema->resultset('Ticket');
    my $guard = $self->result_source->schema->txn_scope_guard;
    my $fy   = Lenio::FY->new(
        site_id => $params{site_id},
        year    => $params{from},
        schema  => $self->result_source->schema,
    );
    my $dtf  = $self->result_source->schema->storage->datetime_parser;
    my @tickets = $tickets_rs->search({
        'me.site_id'      => $params{site_id},
        'task.global'     => 1,
        'me.cost_planned' => { '!=' => undef },
        'me.completed'    => {
            -between => [
                $dtf->format_datetime($fy->costfrom),
                $dtf->format_datetime($fy->costto),
            ],
        },
    },{
        join => 'task'
    });

    my $year_diff = $params{to} - $params{from};
    my $count;
    foreach my $ticket (@tickets)
    {
        my $planned = $ticket->completed->add(years => $year_diff);
        $tickets_rs->create({
            name          => $ticket->name,
            description   => $ticket->description,
            created_by    => $params{login_id},
            provisional   => $planned,
            contractor_id => $ticket->contractor_id,
            task_id       => $ticket->task_id,
            site_id       => $params{site_id},
            cost_planned  => $ticket->cost_actual,
        });
        $count++;
    }
    $guard->commit;

    notice __nx"One ticket created", "{_count} tickets created", $count;
}

sub site_checks_csv
{   my ($self, $site_id, %options) = @_;
    my $dateformat = $options{dateformat};
    my $csv = Text::CSV->new;
    my @headings = qw/check frequency last_done comments/;
    $csv->combine(@headings);
    my $csvout = $csv->string."\n";
    foreach my $check ($self->site_checks($site_id))
    {
        my @row = (
            $check->name,
            $check->period_qty." ".$check->period_unit.($check->period_qty > 1 ? 's' : undef),
            $check->last_completed->strftime($dateformat),
            undef
        );
        $csv->combine(@row);
        $csvout .= $csv->string."\n";
    }
    return $csvout;
}

sub site_checks
{   my ($self, $site_id) = @_;

    $self->search({
        site_check => 1,
        'site.id'  => $site_id,
        deleted    => undef,
    },{
        join      => {
            site_tasks => ['site', 'checks_done']
        },
        prefetch  => 'check_items',
        group_by  => 'me.id',
        '+select' => [
            {
                max => 'checks_done.datetime', -as => 'last_completed'
            }, {
                max => 'site_tasks.id', -as => 'site_task_id2'
            }
        ],
        '+as' => ['last_completed', 'site_task_id2'],
    })->all;
}

sub overdue
{   my ($self, %options) = @_;

    my $site_id   = $options{site_id};
    my $login     = $options{login};
    local $Lenio::Schema::Result::Task::SITEID = $site_id
        if $site_id;
    my @intervals = qw/year month day/;
    my $schema    = $self->result_source->schema;

    my @tasks;
    foreach my $interval (@intervals)
    {
        my $search = {
            'period_unit' => $interval,
        };
        $search->{global} = 1 unless $options{local};
        $search->{global} = 0 if $login && !$login->is_admin;
        $search->{site_check} = 0; # Don't show site manager checks
        my $s = ref $site_id eq 'ARRAY' ? [ map { $_->id } @$site_id ] : $site_id;
        $search->{'site.id'} = $s if $s;

        my $now = $self->result_source->storage->datetime_parser->format_date(DateTime->now);
        push @tasks, $self->search(
            $search,
            {
                prefetch => {
                    'site_tasks' => [
                        {
                            'site' => 'org'
                        }
                    ]
                },
                '+select' => [
                    { max => $schema->resultset('Ticket')
                        ->search({
                            'metask.site_id' => {
                                -ident => 'site_tasks.site_id'
                            },
                            'metask.task_id' => {
                                -ident => 'site_tasks.task_id'
                            }
                        },
                        {
                            alias => 'metask',
                        })
                        ->get_column('completed')
                        ->max_rs->as_query, -as => 'ticket_completed' },
                    { max => $schema->resultset('Ticket')
                        ->search({
                            'metask.site_id' => {
                                -ident => 'site_tasks.site_id'
                            },
                            'metask.task_id' => {
                                -ident => 'site_tasks.task_id'
                            }
                        },
                        {
                            alias => 'metask',
                        })
                        ->get_column('planned')
                        ->max_rs->as_query, -as => 'ticket_planned' },
                ],
                group_by => [
                    'site_tasks.task_id', 'site_tasks.site_id',
                ],
                having => {
                    'ticket_completed' => [
                        undef, 
                        {
                            '<' => $self->dt_SQL_subtract($self->utc_now, $interval, { -ident => '.period_qty' }),
                        },
                    ],
                }
            }
        )->all;
    }

    # Unfortunately sorting cannot be done in the database, as we're doing
    # a few sql runs to get all the results.
    my @all_tasks;

    foreach my $task (@tasks)
    {
        foreach my $site_task ($task->site_tasks)
        {
            my $parser = $self->result_source->storage->datetime_parser;
            my $ticket_planned_raw = $task->get_column('ticket_planned');
            my $ticket_planned     = $ticket_planned_raw && $parser->parse_date($ticket_planned_raw);
            my $ticket_completed_raw = $task->get_column('ticket_completed');
            my $ticket_completed     = $ticket_completed_raw && $parser->parse_date($ticket_completed_raw);
            push @all_tasks, {
                id             => $task->id,
                name           => $task->name,
                global         => $task->global,
                task           => $task,
                site           => $site_task->site,
                last_planned   => $ticket_planned,
                last_completed => $ticket_completed,
            };
        }
    }

    $options{sort} ||= '';

    if ($options{sort} eq 'org')
    { @all_tasks = sort { $a->{site}->org->name cmp $b->{site}->org->name } @all_tasks
    }
    elsif ($options{sort} eq 'planned')
    { @all_tasks = sort
        {
            # Having undef DateTimes seems to not work when sorting
            ($a->{last_planned} ? $a->{last_planned}->epoch : 0)
            <=>
            ($b->{last_planned} ? $b->{last_planned}->epoch : 0)
        } @all_tasks
    }
    elsif ($options{sort} eq 'completed')
    { @all_tasks = sort
        {
            # Having undef DateTimes seems to not work when sorting
            ($a->{last_completed} ? $a->{last_completed}->epoch : 0)
            <=>
            ($b->{last_completed} ? $b->{last_completed}->epoch : 0)
        } @all_tasks
    }
    else
    { @all_tasks = sort { $a->{task}->name cmp $b->{task}->name } @all_tasks
    }

    @all_tasks = reverse @all_tasks if $options{sort_desc};

    @all_tasks;
}

sub csv
{   my ($self, %options) = @_;
    my $dateformat = $options{dateformat};
    my $csv = Text::CSV->new;
    my @headings = qw/task frequency_qty frequency_unit contractor last_done next_due cost_planned cost_actual/;
    $csv->combine(@headings);
    my $csvout = $csv->string."\n";
    my $task_completed = $self->last_completed(site_id => $options{site_id}, global => 1);
    my ($cost_planned_total, $cost_actual_total);
    foreach my $task ($self->summary(%options, onlysite => 1))
    {
        my $last_done = $task_completed->{$task->id} && $task_completed->{$task->id};
        my $next_due  = $last_done && $last_done->clone->add($task->period_unit.'s' => $task->period_qty);
        my @row = (
            $task->name,
            $task->period_qty,
            $task->period_unit,
            $task->contractor_name,
            $last_done && $last_done->strftime($dateformat),
            $next_due && $next_due->strftime($dateformat),
            $task->cost_planned,
            $task->cost_actual,
        );
        $csv->combine(@row);
        $csvout .= $csv->string."\n";
        $cost_planned_total += $task->cost_planned;
        $cost_actual_total += $task->cost_actual;
    }
    $csv->combine('','','','','','Totals:',sprintf("%.2f", $cost_planned_total),sprintf("%.2f", $cost_actual_total));
    $csvout .= $csv->string."\n";
    return $csvout;
}

sub _price
{    my $f = new Number::Format(
        -int_curr_symbol => '£',
    );
    $f->format_price(shift);
}

sub _pdf
{   my ($self, %options) = @_;
    my $pdf = CtrlO::PDF->new(
        logo         => $options{logo},
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
    $pdf->heading($options{company});
    $pdf->heading($options{title}, bottommargin => 20);
    my $org = $options{site}->org;
    $pdf->text($org->full_address);

    $pdf;
}

sub _task_tables
{   my ($self, %options) = @_;
    my @tables; my @data; my $last_tasktype; my $subtotal = 0;
    my $site = $options{site};
    my $task_completed = $self->last_completed(site_id => $site->id, global => 1);
    foreach my $task ($self->summary(site_id => $site->id, onlysite => 1, global => 1, fy => $options{fy}))
    {
        my $tasktype = $task->tasktype_name;
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

        my $last_done = $task_completed->{$task->id} && $task_completed->{$task->id};
        my $next_due  = $last_done && $last_done->clone->add($task->period_unit.'s' => $task->period_qty);
        my $price;
        if ($options{finsum})
        {
            $price = defined $task->cost_actual
                ? $task->cost_actual
                : defined $task->cost_planned
                ? $task->cost_planned
                : undef,
            push @data, [
                $task->name,
                $last_done && $last_done->strftime($options{dateformat}),
                defined $price ? _price($price) : undef,
                $task->period,
                $task->contractor_name,
                $task->description,
            ];
        }
        else {
            $price = $task->cost_planned;
            push @data, [
                $task->name,
                defined $price ? _price($price) : undef,
                $task->period,
                $task->contractor_name,
                $next_due && $next_due->strftime($options{dateformat}),
                $task->description,
            ];
        }
        $subtotal += ($price || 0);

        $last_tasktype = $tasktype;
    }
    push @tables, {
        name => $last_tasktype,
        data => [@data], # Copy
        total => $subtotal,
    };
    return @tables;
}

sub sla
{   my ($self, %options) = @_;

    my $site = $options{site};

    my $pdf = $self->_pdf(%options, title => 'Service Contract Agreement');

    my @tables = $self->_task_tables(%options);

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
            'Cost',
            'Frequency',
            'Contractor',
            'Due',
            'Notes',
        ];
        $pdf->table(
            data         => $data,
            header_props => $hdr_props,
            font_size    => 8,
        );
        $pdf->text("<b>Total cost: "._price($table->{total})."</b>", indent => 350, size => 10);
        $total += $table->{total};
    }

    $pdf->heading("Total fee for service contract: "._price($total)." +VAT", size => 14);

    $pdf->heading("Contract Agreement", size => 12, topmargin => 15);
    $pdf->text($options{sla_notes});

    $pdf->heading("Signed", size => 12, topmargin => 15);
    my $y = $pdf->y_position;
    $pdf->text("On behalf of ".$site->org->name);
    $pdf->text("Position:");
    $pdf->text("Date:");
    $pdf->text("<u>Signature:</u>");
    $pdf->set_y_position($y);
    $pdf->text("On behalf of $options{company}", indent => 250);
    $pdf->text("Position:", indent => 250);
    $pdf->text("Date:", indent => 250);
    $pdf->text("Signature:", indent => 250);

    $pdf->add_page;
    $pdf->heading('Excluded service items');
    $pdf->text('The following items are not included as part of the service package');
    my @data = ([
        'Item',
        'Type',
        'Recommended frequency',
        'Notes',
    ]);
    foreach my $task ($self->summary(site_id => $site->id, excluded => 1, global => 1))
    {
        push @data, [
            $task->name,
            $task->tasktype_name,
            $task->period,
            $task->description,
        ];
    }
    $pdf->table(
        data         => \@data,
        header_props => $hdr_props,
        font_size    => 8,
    );

    return $pdf;
}

sub finsum
{   my ($self, %params) = @_;

    my $pdf = $self->_pdf(%params, title => 'Financial Summary');

    my $site = $params{site};

    my @tickets = $self->result_source->schema->resultset('Ticket')->summary(
        site_id        => $site->id,
        fy             => $params{fy},
        task_tickets   => 0,
        cost_only      => 1,
        completed_only => 1,
        sort           => 'type',
    );
    my @tables; my @data; my $last_tasktype; my $subtotal = 0; my $is_reactive;

    foreach my $ticket (@tickets)
    {
        my $tasktype = $ticket->task ? $ticket->task->tasktype_name : 'Reactive maintenance';
        if (defined $last_tasktype && $tasktype ne $last_tasktype)
        {
            push @tables, {
                name        => $last_tasktype,
                data        => [@data], # Copy
                total       => $subtotal,
                is_reactive => $is_reactive,
            };
            $subtotal = 0;
            @data = ();
        }
        $is_reactive = $tasktype eq 'Reactive maintenance';

        my @d = (
            $ticket->name,
            $ticket->completed ? $ticket->completed->strftime($params{dateformat}) : undef,
            defined $ticket->cost_actual ? _price($ticket->cost_actual) : undef,
            $ticket->contractor ? $ticket->contractor->name : undef,
        );
        push @d, $ticket->description
            unless $is_reactive;
        unshift @d, $ticket->id
            if $is_reactive;
        push @data, \@d;

        $subtotal += ($ticket->cost_actual || 0);

        $last_tasktype = $tasktype;
    }

    push @tables, {
        name        => $last_tasktype,
        data        => [@data], # Copy
        total       => $subtotal,
        is_reactive => $is_reactive,
    };

    push @tables, $self->_task_tables(%params, finsum => 1);

    my $hdr_props = {
        repeat     => 1,
        font_size  => 8,
    };

    my $total = 0; my $total_reactive = 0;
    foreach my $table (@tables)
    {
        $pdf->heading($table->{name}, size => 12, topmargin => 10, bottommargin => 0);
        my $data = $table->{data};
        my @headings = $table->{is_reactive}
            ? (
                'ID',
                'Item',
                'Date',
                'Cost',
                'Contractor',
            ) : (
                'Item',
                'Last done',
                'Cost',
                'Period',
                'Contractor',
                'Notes'
            );
        unshift @$data, \@headings;
        $pdf->table(
            data         => $data,
            header_props => $hdr_props,
            font_size    => 8,
        );
        $pdf->text("<b>Total cost: "._price($table->{total})."</b>", indent => 350, size => 10);
        if ($table->{is_reactive})
        {
            $total_reactive += $table->{total};
        }
        else {
            $total += $table->{total};
        }
    }

    $pdf->heading("Total reactive costs: "._price($total_reactive)." +VAT", size => 14);
    $pdf->heading("Total service item costs: "._price($total)." +VAT", size => 14);

    $pdf;
}

1;
