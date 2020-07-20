package Lenio::Schema::ResultSet::Task;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use utf8; # Needed for £ symbols in PDF

use CtrlO::PDF;
use DateTime;
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

sub global
{   my $self = shift;
    $self->search_rs({
        global => 1,
    },{
        order_by => 'me.name',
    });
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
                completed => [
                    -and =>
                        { '>=' => $dtf->format_datetime($from) },
                        { '<'  => $dtf->format_datetime($to) },
                ],
                -and => [
                    planned => [
                        -and =>
                            { '>=' => $dtf->format_datetime($from) },
                            { '<'  => $dtf->format_datetime($to) },
                    ],
                    completed => undef,
                ],
                -and => [
                    provisional => [
                        -and =>
                            { '>=' => $dtf->format_datetime($from) },
                            { '<'  => $dtf->format_datetime($to) },
                    ],
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
    my $having = $options{contractor_ids} && @{$options{contractor_ids}}
        ? { contractor_id => $options{contractor_ids} }
        : undef;

    $self->search($search, {
        order_by => $order_by,
        prefetch => [
            'tasktype',
            {
                site_tasks => 'site'
            },
        ],
        select => [
            'me.id', 'me.name', 'me.description', 'me.period_unit', 'me.period_qty', 'me.global',
            'me.contractor_requirements', 'me.evidence_required', 'me.statutory', 'me.site_check',
            'site_tasks.site_id',
            # This next block selects the contractor of the most recent ticket
            # in the relevant selection
            {
                "" => $schema->resultset('Ticket')->search({
                    'ticket.id' => {'=' => $schema->resultset('Task')
                        ->correlate('tickets')
                        ->search({ site_id => $site_id, -or => [@dates] })
                        ->get_column('id')
                        ->max_rs->as_query}
                },{
                    alias    => 'ticket', # Prevent conflict with other "me" table
                    prefetch => 'contractor',
                })->get_column('contractor.name')->max_rs->as_query,
                -as => 'contractor_name',
            },
            # This next block selects the contractor ID of the most recent ticket
            # in the relevant selection
            {
                "" => $schema->resultset('Ticket')->search({
                    'ticket2.id' => {'=' => $schema->resultset('Task')
                        ->correlate('tickets')
                        ->search({ site_id => $site_id, -or => [@dates] })
                        ->get_column('id')
                        ->max_rs->as_query}
                },{
                    alias    => 'ticket2', # Prevent conflict with other "me" table
                })->get_column('contractor_id')->max_rs->as_query,
                -as => 'contractor_id',
            }
        ],
        as => [qw/
            id name description period_unit period_qty global
            contractor_requirements evidence_required statutory
            site_check site_tasks.site_id contractor_name contractor_id
        /],
         having => $having,
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
                ->search({ site_id => $site_id, completed => undef, planned => { '!=' => undef } }) # Next regardless of date options
                ->get_column('planned')
                ->max_rs->as_query,
            next_planned_id => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id, completed => undef, planned => { '!=' => undef } }) # Next regardless of date options
                ->get_column('id')
                ->max_rs->as_query,
            has_provisional => $schema->resultset('Task')
                ->correlate('tickets')
                ->search({ site_id => $site_id, completed => undef, planned => undef, provisional => { '!=' => undef } }) # Next regardless of date options
                ->count_rs->as_query,
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

sub site_tasks_grouped
{   my ($self, %args) = @_;

    if (my $site_ids = $args{site_ids})
    {
        my @all = $self->search({
            'site_tasks.site_id' => $site_ids,
            'task.global'        => 1,
        },{
            prefetch => {
                site_tasks => [
                    'site',
                    {
                        task => 'tasktype',
                    }
                ]
            },
            order_by => ['tasktype.name', 'task.name'],
        })->all;
        my @types; my @tasks; my $last_type;
        foreach my $task (@all)
        {
            if ($last_type && $task->tasktype->name ne $last_type)
            {
                push @types, {
                    name  => $last_type,
                    tasks => [@tasks],
                };
                @tasks = ();
            }
            push @tasks, $task;
            $last_type = $task->tasktype->name;
        }
        return @types, {
            name  => $last_type,
            tasks => [@tasks],
        };
    }
}

sub populate_tickets
{   my ($self, %params) = @_;
    my $tickets_rs = $self->result_source->schema->resultset('Ticket');
    my $guard = $self->result_source->schema->txn_scope_guard;
    my $fy_from = Lenio::FY->new(
        site_id => $params{site_id},
        year    => $params{from},
        schema  => $self->result_source->schema,
    );
    my $fy_to = Lenio::FY->new(
        site_id => $params{site_id},
        year    => $params{to},
        schema  => $self->result_source->schema,
    );
    my $dtf  = $self->result_source->schema->storage->datetime_parser;
    my @tickets = $tickets_rs->search({
        'me.site_id'      => $params{site_id},
        'task.global'     => 1,
        'me.cost_planned' => { '!=' => undef },
        'me.completed'    => [
            -and =>
                { '>=' => $dtf->format_datetime($fy_from->costfrom) },
                { '<'  => $dtf->format_datetime($fy_from->costto) },
        ],
    },{
        join => 'task'
    });

    my $year_diff = $params{to} - $params{from};
    my $count = 0; # Ensure not undef if no tickets created
    foreach my $ticket (@tickets)
    {
        my $planned = $ticket->completed->add(years => $year_diff);
        # Skip if the planned date will take us outside of the year we are
        # populating
        next if $planned < $fy_to->costfrom || $planned > $fy_to->costto;
        $tickets_rs->create({
            name          => $ticket->name,
            description   => $ticket->description,
            created_by    => $params{login_id},
            created_at    => DateTime->now,
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
        $search->{'site.id'} = $site_id if $site_id;

        my $now = $self->result_source->storage->datetime_parser->format_date(DateTime->now);
        # Prefetch doesn't really work here, as the get_column of the special
        # subquery columns do not seem to respect a null value if it is fetched
        # via site_tasks()
        push @tasks, $self->search(
            $search,
            {
                join => {
                    'site_tasks' => [
                        {
                            'site' => 'org'
                        }
                    ]
                },
                'select' => [
                    'me.id',
                    'me.name',
                    'me.period_qty',
                    'me.period_unit',
                    { "" => 'site.name', -as => 'site_name' },
                    { "" => 'site.id', -as => 'site_id' },
                    { "" => 'org.name', -as => 'org_name' },
                    { "" => 'org.id', -as => 'org_id' },

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
                            alias    => 'metask',
                            order_by => { -desc => 'metask.completed' },
                            rows     => 1,
                        })
                        ->get_column('id')
                        ->as_query, -as => 'ticket_completed_id' },
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
                            alias    => 'metask',
                            order_by => { -desc => 'metask.planned' },
                            rows     => 1,
                        })
                        ->get_column('id')
                        ->as_query, -as => 'ticket_planned_id' },
                    { max => $schema->resultset('Ticket')
                        ->search({
                            'metask.site_id' => {
                                -ident => 'site_tasks.site_id'
                            },
                            'metask.task_id' => {
                                -ident => 'site_tasks.task_id'
                            },
                            'metask.completed' => undef,
                            'metask.planned'   => undef,
                        },
                        {
                            alias    => 'metask',
                            order_by => { -asc => 'metask.id' },
                            rows     => 1,
                        })
                        ->get_column('provisional')
                        ->as_query, -as => 'ticket_provisional' },
                    { max => $schema->resultset('Ticket')
                        ->search({
                            'metask.site_id' => {
                                -ident => 'site_tasks.site_id'
                            },
                            'metask.task_id' => {
                                -ident => 'site_tasks.task_id'
                            },
                            'metask.completed' => undef,
                            'metask.planned'   => undef,
                        },
                        {
                            alias    => 'metask',
                            order_by => { -asc => 'metask.id' },
                            rows     => 1,
                        })
                        ->get_column('id')
                        ->as_query, -as => 'ticket_provisional_id' },
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
                    ticket_planned => [
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
        my $parser = $self->result_source->storage->datetime_parser;
        my $ticket_provisional_raw = $task->get_column('ticket_provisional');
        my $ticket_provisional     = $ticket_provisional_raw && $parser->parse_date($ticket_provisional_raw);
        my $ticket_planned_raw     = $task->get_column('ticket_planned');
        my $ticket_planned         = $ticket_planned_raw && $parser->parse_date($ticket_planned_raw);
        my $ticket_completed_raw   = $task->get_column('ticket_completed');
        my $ticket_completed       = $ticket_completed_raw && $parser->parse_date($ticket_completed_raw);
        push @all_tasks, {
            id                => $task->id,
            name              => $task->name,
            global            => $task->global,
            task              => $task,
            site              => {
                id   => $task->get_column('site_id'),
                name => $task->get_column('site_name'),
                org  => {
                    id   => $task->get_column('org_id'),
                    name => $task->get_column('org_name'),
                },
            },
            first_provisional    => $ticket_provisional,
            first_provisional_id => $task->get_column('ticket_provisional_id'),
            last_planned         => $ticket_planned,
            last_planned_id      => $task->get_column('ticket_planned_id'),
            last_completed       => $ticket_completed,
            last_completed_id    => $task->get_column('ticket_completed_id'),
        };
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
        logo_scaling => 0.15,
        orientation  => $options{orientation} || "portrait", # Default
        top_padding  => 50,
        #footer      => "My PDF document footer",
    );

    # Add a page
    $pdf->add_page;
    # For the first page, move the cursor back up the page to remove the top_padding
    $pdf->move_y_position(50);

    my $fy = Lenio::FY->new(site_id => $options{site}->id, year => $options{fy}, schema => $self->result_source->schema);
    my $period = $fy->costfrom->strftime("%d %B %Y")." to ".$fy->costto->strftime("%d %B %Y");

    # Add headings
    $pdf->heading($options{company});
    $pdf->heading($options{title});
    $pdf->heading($period, bottommargin => 20, size => 14);
    my $org = $options{site}->org;
    $pdf->text($org->full_address);

    $pdf;
}

sub _task_tables
{   my ($self, %options) = @_;
    my @tables; my @data; my $last_tasktype; my $subtotal_planned = 0; my $subtotal_actual = 0;
    my $site = $options{site};
    my $task_completed = $self->last_completed(site_id => $site->id, global => 1);
    foreach my $task ($self->summary(site_id => $site->id, onlysite => 1, global => 1, fy => $options{fy}))
    {
        my $tasktype = $task->tasktype_name;
        if (defined $last_tasktype && $tasktype ne $last_tasktype)
        {
            push @tables, {
                name          => $last_tasktype,
                data          => [@data], # Copy
                total_planned => $subtotal_planned,
                total_actual  => $subtotal_actual,
            };
            $subtotal_planned = 0;
            $subtotal_actual  = 0;
            @data = ();
        }

        my $last_done = $task_completed->{$task->id} && $task_completed->{$task->id};
        my $next_due  = $last_done && $last_done->clone->add($task->period_unit.'s' => $task->period_qty);
        my ($price_planned, $price_actual);
        if ($options{finsum})
        {
            $price_planned = $task->cost_planned;
            $price_actual  = $task->cost_actual;
            push @data, [
                $task->name,
                $next_due && $next_due->strftime($options{dateformat}),
                $task->next_planned && $task->next_planned->strftime($options{dateformat}),
                $task->last_completed && $task->last_completed->strftime($options{dateformat}),
                defined $price_planned ? _price($price_planned) : undef,
                defined $price_actual ? _price($price_actual) : undef,
                $task->period,
                $task->contractor_name,
            ];
        }
        else {
            $price_planned = $task->cost_planned;
            push @data, [
                $task->name,
                $task->description,
                $task->period,
                $task->contractor_requirements,
                $task->evidence_required,
                $task->contractor_name,
                defined $price_planned ? _price($price_planned) : undef,
                $next_due && $next_due->strftime($options{dateformat}),
                $task->statutory,
            ];
        }
        $subtotal_planned += ($price_planned || 0);
        $subtotal_actual  += ($price_actual || 0);

        $last_tasktype = $tasktype;
    }
    push @tables, {
        name          => $last_tasktype,
        data          => [@data], # Copy
        total_planned => $subtotal_planned,
        total_actual  => $subtotal_actual,
    };
    return @tables;
}

sub sla
{   my ($self, %options) = @_;

    my $site = $options{site};

    my $pdf = $self->_pdf(%options, title => 'Service Contract Agreement', orientation => 'landscape');

    my @tables = $self->_task_tables(%options, sla => 1);

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
            'Description',
            'Frequency',
            'Contractor Requirements',
            'Evidence Required',
            'Contractor',
            'Cost',
            'Due',
            'Statutory/ Regulatory/ Industry Code/ Good Practice',
        ];
        $pdf->table(
            data         => $data,
            header_props => $hdr_props,
            font_size    => 8,
        );
        $pdf->text("<b>Total cost: "._price($table->{total_planned})."</b>", indent => 500, size => 10);
        $total += $table->{total_planned};
    }

    $pdf->heading("Total fee for service contract: "._price($total)." +VAT", size => 14);

    $pdf->add_page;
    $pdf->heading("Signature of Service Level Agreement", size => 12, topmargin => 15);
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
    $pdf->text('EXCLUSIONS: In accordance with the Terms and Conditions of this SLA the items highlighted in "Excluded Service Items" are not included within the SLA Agreement. They are either not applicable to the schools and/ or will be managed and competed by the school premises team directly.');
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

    my $site = $params{site};

    my $fy = Lenio::FY->new(site_id => $site->id, year => $params{fy}, schema => $self->result_source->schema);
    my $period = $fy->costfrom->strftime($params{dateformat})." to ".$fy->costto->strftime($params{dateformat});
    my $pdf = $self->_pdf(%params, title => 'Financial Summary', period => $period);

    my @tickets = $self->result_source->schema->resultset('Ticket')->summary(
        site_id        => $site->id,
        fy             => $params{fy},
        task_tickets   => 0,
        cost_only      => 1,
        sort           => 'type',
        filter         => {
            status => {
                completed => 1,
            },
            type => {
                reactive => 1,
            },
        },
    );
    my @tables; my @data; my $last_tasktype; my $subtotal_planned = 0; my $subtotal_actual; my $is_reactive;

    foreach my $ticket (@tickets)
    {
        my $tasktype = $ticket->task ? $ticket->task->tasktype_name : 'Reactive maintenance';
        if (defined $last_tasktype && $tasktype ne $last_tasktype)
        {
            push @tables, {
                name          => $last_tasktype,
                data          => [@data], # Copy
                total_planned => $subtotal_planned,
                total_actual  => $subtotal_actual,
                is_reactive   => $is_reactive,
            };
            $subtotal_planned = 0; $subtotal_actual = 0;
            @data = ();
        }
        $is_reactive = $tasktype eq 'Reactive maintenance';

        my @d = (
            $ticket->name,
            $ticket->completed ? $ticket->completed->strftime($params{dateformat}) : undef,
            defined $ticket->cost_planned ? _price($ticket->cost_planned) : undef,
            defined $ticket->cost_actual ? _price($ticket->cost_actual) : undef,
            $ticket->contractor ? $ticket->contractor->name : undef,
        );
        unshift @d, $ticket->id
            if $is_reactive;
        push @data, \@d;

        $subtotal_planned += ($ticket->cost_planned || 0);
        $subtotal_actual  += ($ticket->cost_actual || 0);

        $last_tasktype = $tasktype;
    }

    push @tables, {
        name          => $last_tasktype,
        data          => [@data], # Copy
        total_planned => $subtotal_planned,
        total_actual  => $subtotal_actual,
        is_reactive   => $is_reactive,
    };

    push @tables, $self->_task_tables(%params, finsum => 1);

    my $hdr_props = {
        repeat     => 1,
        font_size  => 8,
    };

    my $total_planned = 0; my $total_actual = 0; my $total_reactive_planned = 0; my $total_reactive_actual = 0;
    foreach my $table (@tables)
    {
        $pdf->heading($table->{name}, size => 12, topmargin => 10, bottommargin => 0);
        my $data = $table->{data};
        my @headings = $table->{is_reactive}
            ? (
                'ID',
                'Item',
                'Date',
                'Planned cost',
                'Actual cost',
                'Contractor',
            ) : (
                'Item',
                'Service due',
                'Service planned',
                'Service completed',
                'Planned cost',
                'Actual cost',
                'Frequency',
                'Contractor',
            );
        unshift @$data, \@headings;
        my $cellprops = [];
        foreach my $row (@$data)
        {
            push @$cellprops, !$table->{is_reactive} && $row->[3]
                ? [({background_color => '#77dd77'}) x @$row]
                : [(undef) x @$row];
        }
        $pdf->table(
            data         => $data,
            header_props => $hdr_props,
            cell_props   => $cellprops,
            font_size    => 8,
        );
        $pdf->text("<b>Total planned cost: "._price($table->{total_planned})."</b>", indent => 350, size => 10);
        $pdf->text("<b>Total actual cost: "._price($table->{total_actual})."</b>", indent => 350, size => 10);
        if ($table->{is_reactive})
        {
            $total_reactive_planned += $table->{total_planned};
            $total_reactive_actual += $table->{total_actual};
        }
        else {
            $total_planned += $table->{total_planned};
            $total_actual  += $table->{total_actual};
        }
    }

    $pdf->heading("Agreed total cost of service contract: "._price($total_planned)." +VAT", size => 16);
    $pdf->heading("Total actual annual cost to date: "._price($total_actual)." +VAT", size => 16);
    $pdf->heading("Total Cost of Service Contract + Reactive Maintenance Call outs total cost: "
        ._price($total_actual + $total_reactive_actual)." +VAT", size => 16);

    $pdf;
}

1;
