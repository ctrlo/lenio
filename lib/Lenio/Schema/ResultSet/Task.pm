package Lenio::Schema::ResultSet::Task;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use Lenio::FY;

__PACKAGE__->load_components(qw(ResultSet::ParameterizedJoinHack Helper::ResultSet::DateMethods1));

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

    my $site_id = $options{site_id};
    my $search  = { site_check => 0 };
    $search->{'site_single_tasks_undef.site_id'} = $site_id if $options{onlysite};
    $search->{global}  = $options{global} if exists $options{global};

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
            );
        }
        # Also search for tickets without a planned date (in order to
        # add costs), but only if currently viewed dates are this FY year.
        # This is so that tasks can be allocated estimated costs, but without
        # needing a planned date on the ticket that has been raised.
        push @dates, (
            -and => [
                completed => undef,
                planned   => undef,
            ],
        ) if $fy && (DateTime->compare(DateTime->now, $from) > 0)
           && (DateTime->compare(DateTime->now, $to) < 0);
        # Finally add on any tasks without any tickets, which would otherwise
        # not appear in the summary.
        push @dates, (
            -and => [
                'ticket.completed'    => undef,
                'ticket.planned'      => undef,
                'ticket.cost_actual'  => undef,
                'ticket.cost_planned' => undef,
            ],
        );
    }
    $search->{'-or'} = [ @dates ] if @dates;


    $self->with_parameterized_join(
        site_single_tasks => {
            site_id   => $site_id,
        }
    )->with_parameterized_join(
        site_single_tasks_undef => {
            site_id   => $site_id,
        }
    )->search($search, {
        order_by => [
            'tasktype.name', 'me.name'
        ],
        group_by => 'me.id',
        prefetch => [
            'tasktype',
            {
                site_single_tasks => [qw/site ticket/]
            },
            'site_single_tasks_undef',
        ],
        select => [
            'me.id', 'me.name', 'me.description', 'me.period_unit', 'me.period_qty', 'me.global', 'me.site_check',
            'site_single_tasks.site_id', 'site_single_tasks.id',
            {
                max => 'ticket.completed',
                -as => 'last_completed'
            }, {
                max => 'ticket.planned',
                -as => 'last_planned'
            }, {
                sum => 'ticket.cost_planned',
                -as => 'cost_planned'
            }, {
                sum => 'ticket.cost_actual',
                -as => 'cost_actual'
            },
        ],
    })->all;
}

sub site_checks
{   my ($self, $site_id) = @_;

    my @checks;
    if ($site_id)
    {
        @checks = $self->search({
            site_check => 1,
            'site.id'  => $site_id,
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
    else {
        @checks = $self->search({
            site_check => 1,
        },{
            order_by => 'me.name',
        })->all;
    }
}

sub overdue
{   my ($self, %options) = @_;

    my $site_id = $options{site_id};
    my @intervals = qw/year month week day/;

    my @tasks;
    foreach my $interval (@intervals)
    {
        my $search = {
            'period_unit' => $interval,
        };
        $search->{global} = 1 unless $options{local};
        $search->{site_check} = 0; # Don't show site manager checks
        my $s = ref $site_id eq 'ARRAY' ? [ map { $_->id } @$site_id ] : $site_id;
        $search->{'site.id'} = $s if $s;

        my $now = $self->result_source->storage->datetime_parser->format_date(DateTime->now);
        push @tasks, $self->search(
            $search,
            {
                prefetch => {
                    'site_tasks' => [
                        'ticket', {
                            'site' => 'org'
                        }
                    ]
                },
                '+select' => [
                    {
                        max => 'ticket.planned',
                        -as => 'ticket_planned',
                    }, {
                        max => 'ticket.completed',
                        -as => 'ticket_completed',
                    }
                ],
                '+as' => [
                    'site_tasks.last_planned', 'site_tasks.last_completed',
                ],
                group_by => [
                    'site_tasks.task_id', 'site_tasks.site_id',
                ],
                having => {
                    'ticket_completed' => [
                        undef, 
                        {
                            '<' => $self->dt_SQL_add($self->utc_now, $interval, { -ident => '.period_qty' }),
                        },
                    ]
                }
            }
        )->all;
    }
    @tasks;
}

sub _round_to_day
{   shift->clone->set(hour => 0, minute => 0, second => 0);
}

sub calendar_check
{   my ($self, $from, $to, $site_id, $login) = @_;

    my @calendar;
    my $dtf  = $self->result_source->schema->storage->datetime_parser;

    my @done = rset('CheckDone')->search({
        site_id  => $site_id,
        datetime => {
            '>=', $dtf->format_datetime($from),
            '<=', $dtf->format_datetime($to),
        },
    }, {
        prefetch => [ {'site_task' => 'task'}, 'check_items_done'],
        order_by => [qw/me.site_task_id me.datetime/],
    });

    # First fill in all the ones that have actually been done.
    # We also interpolate between when there is a gap.
    my $previous; my $last_id;
    foreach my $check (@done)
    {
        $previous  = undef if !$last_id || $last_id != $check->site_task_id;
        my $qty    = $check->site_task->task->period_qty;
        my $unit   = $check->site_task->task->period_unit."s";
        my $status = (grep { $_->status == 0 } $check->check_items_done)
                   ? 'check-notdone'
                   : $check->check_items_done->count != $check->site_task->task->check_items->count
                   ? 'check-partdone'
                   : 'check-done';

        if ($previous)
        {
            $previous->add( $unit => $qty );
            # Check whether there is a check missing between this one and the previous.
            # Round dates, otherwise a check completed at 8am one day and 10am the next
            # will show as being not completed.
            while (DateTime->compare(
                _round_to_day($check->datetime),
                _round_to_day($previous),
            ) > 0)
            {
                my $dt = $previous->clone;
                $dt->add( days => 1 )
                    if $unit eq 'months' && $dt->day_of_week == 7;
                $dt->add( days => 2 )
                    if $unit eq 'months' && $dt->day_of_week == 6;
                push @calendar, {
                    id          => $check->site_task->task->id,
                    title       => $check->site_task->task->name,
                    url         => "/check/".$check->site_task->task->id,
                    start       => _round_to_day($dt)->epoch * 1000,
                    end         => _round_to_day($dt)->epoch * 1000,
                    class       => 'check-notdone',
                } unless $dt->day_of_week > 5; # Not weekend
                $previous->add( $unit => $qty );
            }
        }
        else {
            # It's the first in the series for this month, so fill in any
            # previous ones not done, but only if it's been done in a
            # previous month
            my $first = $check->datetime->clone->subtract( $unit => $qty );
            while (DateTime->compare($first, $from) >= 0)
            {
                my $count = rset('CheckDone')->search({
                    site_task_id => $check->site_task_id,
                    datetime     => { '<', $dtf->format_datetime($from) },
                })->count;
                my $clone = $first->clone;
                $clone->add( days => 1 )
                    if $unit eq 'months' && $clone->day_of_week == 7;
                $clone->add( days => 2 )
                    if $unit eq 'months' && $clone->day_of_week == 6;
                push @calendar, {
                    id          => $check->site_task->task->id,
                    title       => $check->site_task->task->name,
                    url         => "/check/".$check->site_task->task->id,
                    start       => _round_to_day($clone)->epoch * 1000,
                    end         => _round_to_day($clone)->epoch * 1000,
                    class       => 'check-notdone',
                } if $count && $clone->day_of_week < 6; # Not weekend
                $first->subtract( $unit => $qty );
            }
        }

        # Only show actual time if check is completed. Otherwise
        # show just the day
        my $ctime = $status eq 'check-notdone'
                  ? _round_to_day($check->datetime)->clone
                  : $check->datetime->clone;
        $ctime->add( days => 1 )
            if $unit eq 'months' && $ctime->day_of_week == 7;
        $ctime->add( days => 2 )
            if $unit eq 'months' && $ctime->day_of_week == 6;
        my $c = {
            id          => $check->site_task->task->id,
            title       => $check->site_task->task->name,
            url         => "/check/".$check->site_task->task->id."/".$check->id,
            start       => $ctime->epoch * 1000,
            end         => $ctime->epoch * 1000,
            class       => $status,
        };
        # Don't add if it's a check not done and it's the weekend
        push @calendar, $c unless $status eq 'check-notdone' && $ctime->day_of_week > 5;
        $last_id = $check->site_task_id;
        $previous = $check->datetime;
    }

    my @site_checks = Lenio::Task->site_checks($site_id);

    # Now take the very last completed one, and carry on filling
    # out the subsequent ones required.
    foreach my $check (@site_checks)
    {
        next unless $check->{site};
        my ($done) = rset('CheckDone')->search({
            'task.id' => $check->{id},
            'site_task.site_id' => $site_id,
        },{
            'prefetch' => { 'site_task' => 'task' },
            '+select' => { max => 'me.datetime', -as => 'last_done' },
            '+as'     => 'last_done',
        })->all;

        my $ld = $done->get_column('last_done');
        # If not ever done, start it off from today
        my $last_done = $ld ? $dtf->parse_datetime($ld) : DateTime->now;
        my $qty  = $done->site_task->task->period_qty;
        my $unit = $done->site_task->task->period_unit."s";
        while (DateTime->compare($to, $last_done) >= 0)
        {
            # Keep adding until end of this range.
            $last_done->add( $unit => $qty );
            my $clone = $last_done->clone;
            $clone->add( days => 1 )
                if $unit eq 'months' && $clone->day_of_week == 7;
            $clone->add( days => 2 )
                if $unit eq 'months' && $clone->day_of_week == 6;
            next if (DateTime->compare($from, $clone) > 0); # Last done before this range
            my $status
                = DateTime->compare(DateTime->now, $clone) > 0
                ? 'check-notdone'
                : $qty == 1 && $unit eq 'days'
                ? 'check-due-daily'
                : 'check-due';
            push @calendar, {
                id          => $done->site_task->task->name,
                title       => $done->site_task->task->name,
                url         => "/check/".$done->site_task->task->id,
                start       => _round_to_day($clone)->epoch * 1000,
                end         => _round_to_day($clone)->epoch * 1000,
                class       => $status,
            } if DateTime->compare($to, $clone) > 0 && $clone->day_of_week < 6; # Not weekend
        }
    }
    @calendar;
}

sub calPopulate($$)
{   my ($self,$task,$site) = @_;
    return unless $task->{completed} || $task->{planned};

    my $id  = $task->{ticket_id}
            ? "ticket$task->{ticket_id}"
            : "task$task->{task_id}";
    my $url = $task->{ticket_id}
            ? "/ticket/view/$task->{ticket_id}"
            : "/ticket/new/$task->{task_id}/".$site->id."/" . $task->{due}->ymd('-');
    my $t = {
        id    => $id,
        title => "$task->{name} (".$site->name.")",
        url   => $url
    };

    if ( $task->{due} ) {
        if ( DateTime->compare( $task->{due}, DateTime->now ) < 0
            || $task->{overdue} )
        {
            $t->{class} = 'event-important';
        }
        else {
            $t->{class} = 'event-warning';
        }
        $t->{start} = $task->{due}->epoch * 1000;
        $t->{end}   = $task->{due}->epoch * 1000 + 86400;
    }
    else {
        if ( $task->{completed} ) {
            $t->{class} = 'event-success';
            $t->{start} = $task->{completed}->epoch * 1000;
            $t->{end}   = $task->{completed}->epoch * 1000;
        }
        else {
            $t->{class} = $task->{task_id} ? 'event-info' : 'event-special';
            $t->{start} = $task->{planned}->epoch * 1000;
            $t->{end}   = $task->{planned}->epoch * 1000;
        }

    }
    $t;
}

1;
