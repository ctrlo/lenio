=pod
Lenio - Web-based Facilities Management Software
Copyright (C) 2013 A Beverley

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

package Lenio::Task;

use DBI              ();
use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use DateTime;
use DateTime::Format::DBI;
use DateTime::Format::Strptime;
use Text::Trim;
use Ouch;

use Lenio::Schema;
use Lenio::FY;

my $dtf = schema->storage->datetime_parser;

sub site($)
{   my ($class, $id) = @_;
    my $task_rs = rset('Task');
    my $t = $task_rs->find($id) or return;
    ($t->site_tasks->all)[0]->site_id;
}

sub view($)
{   my ($class, $id) = @_;
    my $task_rs = rset('Task');
    $task_rs->find($id);
}

sub delete($)
{   my ($class, $id) = @_;
    my $task_rs = rset('Task');
    my $t = $task_rs->find($id)
        or ouch 'badid', "The specified ID could not be found";
    rset('SiteTask')->search({ task_id => $id })->delete
        or ouch 'dbfail', "There was a database error when deleting the site/task relations";
    $t->delete
        or ouch 'dbfail', "There was a database error when deleting the task";
}

sub summary
{   my ($self, $site, $args) = @_;

    my $task_rs = rset('SiteSingleTask');
    my $search  = $args->{onlysite} ? {site_id => $site} : {};
    $search->{site_check} = 0;
    my $tasks   = $task_rs->search($search, {
        order_by => 'me.name',
        bind     => [$site],
    });

    my $fy;
    # Work out date to take costs from (ie the financial year)
    $fy = Lenio::FY->new($site, $args->{fy}) if $site;

    my @tasks;
    while (my $task = $tasks->next)
    {
        if (defined $args->{global})
        {
            next unless $args->{global} == $task->global;
        }
        my $t;
        $t->{name}        = $task->get_column('name');
        $t->{id}          = $task->id;
        $t->{period_unit} = $task->period_unit;
        $t->{period_qty}  = $task->period_qty;
        $t->{completed}   = $dtf->parse_date($task->get_column('completed'))
            if $task->get_column('completed');
        $t->{planned}     = $dtf->parse_date($task->get_column('planned'))
            if $task->get_column('planned');
        $t->{site_task_id} = $task->site_task_id;
        $t->{global}      = $task->global;
        $t->{is_extant}   = $task->is_extant == -1 ? 1 : 0;

        if ($site)
        {
            my @dates = (
                completed           => {
                    -between => [
                        $dtf->format_datetime($fy->costfrom),
                        $dtf->format_datetime($fy->costto),
                    ],
                },
                -and => [
                    planned             => {
                        -between => [
                            $dtf->format_datetime($fy->costfrom),
                            $dtf->format_datetime($fy->costto),
                        ],
                    },
                    completed => undef,
                ],
            );
            # Also search for tickets without a planned date (in order to
            # add costs), but only if currently viewed dates are this FY year.
            push @dates, (
                -and => [
                    completed => undef,
                    planned   => undef,
                ],
            ) if (DateTime->compare(DateTime->now, $fy->costfrom) > 0)
                && (DateTime->compare(DateTime->now, $fy->costto) < 0);
            my $c = rset('Ticket')->search(
                {
                    'site_task.task_id' => $task->id,
                    site_id             => $site,
                    -or                 => [ @dates ],
                },{
                    join      => 'site_task',
                    '+select' => { sum => 'me.cost_planned', sum => 'me.cost_actual' },
                    '+as'     => [ 'cost_planned', 'cost_actual' ]
                }
            );
            $t->{cost_planned} = $c->get_column('cost_planned')->sum;
            $t->{cost_actual}  = $c->get_column('cost_actual')->sum;
        }
        push @tasks, $t;
    }
    
    @tasks;
}

sub site_checks
{   my ($self, $site_id) = @_;

    # XXX There is probably a more efficient way of doing
    # this, either with a custom join, or with the new join
    # API for DBIC once it's ready. For now, this will do, and
    # is not much less efficient

    # First get all the site checks
    my @checks = rset('Task')->search({
        site_check => 1,
    },{
            order_by => 'me.name',
    })->all;

    # Now, if site_id is specified, get all the ones
    # for the particular site
    my @site_checks;
    if ($site_id)
    {
        @site_checks = rset('Task')->search({
            site_check => 1,
            'site.id'  => $site_id,
        },{
            join      => { site_tasks => ['site', 'checks_done'] },
            prefetch  => 'check_items',
            group_by  => 'me.id',
            '+select' => [{ max => 'checks_done.datetime', -as => 'last_done' }, { max => 'site_tasks.id', -as => 'site_task_id2'}],
            '+as'     => ['last_done', 'site_task_id2'],
        })->all;
    }

    my $format = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
         time_zone => 'local',
    );

    my @final;
    foreach my $c (@checks)
    {
        my @check_items = $c->check_items;
        my $check = {
            id          => $c->id,
            name        => $c->name,
            description => $c->description,
            check_items => \@check_items,
            period_qty  => $c->period_qty,
            period_unit => $c->period_unit,
        };
        if ($site_id)
        {
            if (my ($sc) = grep {$_->id == $c->id} @site_checks)
            {
                $check->{last_done}    = $format->parse_datetime($sc->get_column('last_done')),
                $check->{site_task_id} = $sc->get_column('site_task_id2');
                $check->{site} = 1;
            }
            else {
                $check->{site} = 0;
            }
        }
        push @final, $check;
    }

    @final;
}

sub check_done
{   my ($self, $login, $params) = @_;

    my $parser = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
         time_zone => 'local',
    );

    my $datetime;
    if ($datetime = $params->{completed})
    {
        $datetime = $parser->parse_datetime($datetime);
        $datetime or ouch 'badparam', "Supplied date $datetime is invalid";
    }

    $datetime = DateTime->now unless $datetime;

    my $done;
    if (my $cid = $params->{check_done_id})
    {
        ($done) = rset('CheckDone')->search({
            id           => $cid,
            site_task_id => $params->{site_task_id},
        }) or ouch 'badparam', "Requested ID $cid not found";
        $done->update({
            datetime => $datetime,
            comment  => $params->{comment},
        });
    }
    else {
        $done = rset('CheckDone')->create({
            site_task_id => $params->{site_task_id},
            login_id     => $login->{id},
            datetime     => $datetime,
            comment      => $params->{comment},
        });
    }

    foreach my $key (keys %$params)
    {
        next unless $key =~ /^item([0-9]+)/;
        my ($existing) = rset('CheckItemDone')->search({
            check_item_id => $1,
            check_done_id => $done->id,
        })->all;
        if ($existing)
        {
            $existing->update({ status => $params->{"item$1"} });
        }
        else {
            rset('CheckItemDone')->create({
                check_item_id => $1,
                check_done_id => $done->id,
                status        => $params->{"item$1"},
            });
        }
    }
}

sub check_update
{   my ($self, $id, $params) = @_;

    if ($params) {
        my $update;
        $update->{name} = $params->{name}
            or ouch 'badparam', "Please provide a name for the check";
        $update->{description} = $params->{description}
            or ouch 'badparam', "Please provide a description for the check";
        $update->{period_qty} = $params->{period_qty}
            or ouch 'badparam', "Please specify the period frequency";
        $update->{period_unit} = $params->{period_unit}
            or ouch 'badparam', "Please specify the period units";

        if ($id)
        {
            my $check = rset('Task')->find($id)
                or ouch 'badid', "Task ID $id could not be found";
            $check->update($update);
        }
        else {
            $update->{site_check} = 1;
            my $check = rset('Task')->create($update);
            $id = $check->id;
        }

        if (my $ci = $params->{checkitem})
        {
            rset('CheckItem')->create({ task_id => $id, name => $ci });
        }
    }
    elsif ($params)
    {
        # Update check items
    }

    my ($check) = rset('Task')->search({ id => $id, site_check => 1 });
    $check;
}

sub check
{   my ($self, $site_id, $task_id, $check_done_id) = @_;

    $task_id or return;

    my $search = {
        'me.id'              => $task_id,
        'site_tasks.site_id' => $site_id,
        site_check           => 1,
    };
    $search->{'checks_done.id'} = $check_done_id if $check_done_id;

    my ($check) = rset('Task')->search($search,
    {
        collapse => 1,
        prefetch => [
            'check_items',
            {
                site_tasks => {
                    checks_done => 'check_items_done'
                }
            }
        ],
    })->all;

    my %done; my $date; my $comment;
    my ($a) = $check->site_tasks;
    my $site_task_id = $a->id;
    if ($check_done_id)
    {
        my ($b) = $a->checks_done;
        $date    = $b->datetime;
        $comment = $b->comment;
        foreach my $d ($b->check_items_done)
        {
            $done{$d->check_item_id} = $d->status;
        }
    }

    my @items;
    foreach my $i ($check->check_items)
    {
        push @items, {
            id => $i->id,
            name => $i->name,
            done => $done{$i->id} || 0,
        };
    }

    {
        id           => $task_id,
        site_task_id => $site_task_id,
        name         => $check->name,
        comment      => $comment,
        items        => \@items,
        date         => $date,
        exists       => $check_done_id ? 1 : 0,
    }
}

sub new($)
{   my ($class, $task) = @_;

    $task->{name}
        or ouch 'badname', "Please provide a name for the task";
    $task->{description}
        or ouch 'baddesc', "Please provide a description for the task";
    $task->{period_qty}
        or ouch 'badperiodqty', "Please specify the period frequency";
    $task->{period_unit}
        or ouch 'badperiodunit', "Please specify the period units";

    $task->{name} = trim($task->{name});

    rset('Task')->create($task)
        or ouch 'dbfail', "There was a database error when creating the task";
}

sub update($$)
{   my ($class, $task) = @_;
    $task->{name}
        or ouch 'badname', "Please provide a name for the task";
    $task->{description}
        or ouch 'baddesc', "Please provide a description for the task";
    $task->{period_qty}
        or ouch 'badperiodqty', "Please specify the period frequency";
    $task->{period_unit}
        or ouch 'badperiodunit', "Please specify the period units";

    $task->{name} = trim($task->{name});
    my $t = rset('Task')->find($task->{id})
        or ouch 'badid', "Unable to find the specified ID";
    $t->update($task)
        or ouch 'dbfail', "There was a database error when updating the task";
}

sub overdue($;$)
{   my ($self, $site, $args) = @_;
    my $task_rs = rset('Task');
    my @intervals = ('year', 'month', 'week', 'day');

    my $format = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
         time_zone => 'local',
    );

    my @tasks;
    foreach my $interval (@intervals)
    {
        my $search =         {
            'period_unit'      => $interval,
        };
        $search->{global} = 1 unless $args->{local};
        $search->{site_check} = 0; # Don't show site manager checks
        my $s = ref $site eq 'ARRAY' ? [ map { $_->id } @$site ] : $site;
        $search->{'site.id'} = $s if $s;

        my $now = $dtf->format_date(DateTime->now);
        my @t = $task_rs->search($search
                ,{ prefetch   => { 'site_tasks' => ['ticket', {'site' => 'org' } ] },
                   '+select'  => [
                                     { max => 'ticket.planned', -as => 'ticket_planned' },
                                     { max => 'ticket.completed', -as => 'ticket_completed' }
                                 ],
                   '+as'      => [ 'site_tasks.ticket_planned', 'site_tasks.ticket_completed' ],
                   group_by   => ['site_tasks.task_id'
                                 ,'site_tasks.site_id'
                                 ],
                   having     => { 'ticket_completed' => [ undef
                                             , { '<', \"DATE_SUB('$now', INTERVAL period_qty $interval)" }
                                             ] }
            }
        )->all;
        foreach my $t (@t)
        {
            foreach my $tt ($t->site_tasks)
            {
                push @tasks, {
                    id               => $tt->task->id,
                    name             => $tt->task->name,
                    site             => $tt->site,
                    ticket_planned   => $format->parse_datetime($tt->get_column('ticket_planned')),
                    ticket_completed => $format->parse_datetime($tt->get_column('ticket_completed')),
                }
            }
        }
    }
    @tasks;
}

sub calendar_check
{   my ($self, $from, $to, $site_id, $login) = @_;

    my @calendar;

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
                $check->datetime->clone->set(hour => 0, minute => 0, second => 0),
                $previous->clone->set(hour => 0, minute => 0, second => 0),
            ) > 0)
            {
                push @calendar, {
                    id          => $check->site_task->task->id,
                    title       => $check->site_task->task->name,
                    url         => "/check/".$check->site_task->task->id,
                    start       => $previous->epoch * 1000,
                    end         => $previous->epoch * 1000,
                    class       => 'check-notdone',
                };
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
                push @calendar, {
                    id          => $check->site_task->task->id,
                    title       => $check->site_task->task->name,
                    url         => "/check/".$check->site_task->task->id,
                    start       => $first->epoch * 1000,
                    end         => $first->epoch * 1000,
                    class       => 'check-notdone',
                } if $count;
                $first->subtract( $unit => $qty );
            }
        }

        my $c = {
            id          => $check->site_task->task->id,
            title       => $check->site_task->task->name,
            url         => "/check/".$check->site_task->task->id."/".$check->id,
            start       => $check->datetime->epoch * 1000,
            end         => $check->datetime->epoch * 1000,
            class       => $status,
        };
        push @calendar, $c;
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
            next if (DateTime->compare($from, $last_done) > 0); # Last done before this range
            my $status
                = DateTime->compare(DateTime->now, $last_done) > 0
                ? 'check-notdone'
                : $qty == 1 && $unit eq 'days'
                ? 'check-due-daily'
                : 'check-due';
            push @calendar, {
                id          => $done->site_task->task->name,
                title       => $done->site_task->task->name,
                url         => "/check/".$done->site_task->task->id,
                start       => $last_done->epoch * 1000,
                end         => $last_done->epoch * 1000,
                class       => $status,
            } if DateTime->compare($to, $last_done) > 0;
        }
    }
    @calendar;
}

sub calendar($$$$)
{   my ($self, $from, $to, $site, $login) = @_;
    my $global = $login->{is_admin} ? 1 : [0, 1];
    my @summary = $self->summary($site);
    my @calendar1; my @calendar2;

    my $ticket_rs = rset('Ticket');
    my @tickets = $ticket_rs->search({ site_id => $site }, {prefetch => {'site_task' => 'task'}});
    foreach my $ticket (@tickets)
    {
        # Skip if logged in as admin and it's a local site task
        next if $login->{is_admin} && $ticket->site_task->task && !$ticket->site_task->task->global;
        my $iss;
        $iss->{name} = $ticket->name;
        $iss->{description} = $ticket->description;
        # Only show completed *or* planned date, preferring completed
        if ($ticket->completed)
        {
            $iss->{completed} = $ticket->completed;
        }
        elsif ($ticket->planned)
        {
            $iss->{planned} = $ticket->planned;
        }
        $iss->{task_id} = $ticket->site_task->task_id;
        $iss->{ticket_id} = $ticket->id;
        push @calendar1, $iss;
    }
    foreach my $task (@summary)
    {
        next if $login->{is_admin} && !$task->{global};
        if ($task->{completed})
        {
            my $period = $task->{period_unit} eq 'year' ? 'years'
                       : $task->{period_unit} eq 'month' ? 'months'
                       : $task->{period_unit} eq 'week' ? 'weeks'
                       : $task->{period_unit} eq 'day' ? 'days'
                       : undef;
            $period or return;
            my $completed = $task->{completed}->clone;
            my $count;
            OUTER:
            while()
            {
                $count++;
                my $ticket_id;
                # Calculate next time it's due
                $task->{period_qty}
                    or ouch 'badparam', "period_qty is zero - will cause infinite loop";
                $completed->add($period => $task->{period_qty});
                last unless DateTime->compare($to, $completed)   > 0;
                foreach my $d (grep { $_->{task_id} && $_->{task_id} == $task->{id} } @calendar1)
                {
                    next unless $d->{planned};
                    my $dur = DateTime::Duration->new( $period => $task->{period_qty} );
                    my $before_comp = $completed->clone->subtract_duration($dur);
                    if (DateTime->compare($before_comp, $d->{planned}) < 0)
                    { 
                        $completed = $d->{planned}->clone; #->clone->add($period => $task->{period_qty});
                        next OUTER;
                     }
                }
                my $newtask = { %$task };
                $newtask->{due} = $completed->clone;
                $newtask->{task_id} = $task->{id};
                $newtask->{overdue} = 1 if DateTime->compare($task->{completed}->clone->add($period => $task->{period_qty}), DateTime->now) < 0; 
                push @calendar2, $newtask if DateTime->compare($completed, $from) > 0;
            }
        }
    }
    (@calendar1, @calendar2);
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
            $t->{end}   = $task->{completed}->epoch * 1000 + 864000;
        }
        else {
            $t->{class} = $task->{task_id} ? 'event-info' : 'event-special';
            $t->{start} = $task->{planned}->epoch * 1000;
            $t->{end}   = $task->{planned}->epoch * 1000 + 86400;
        }

    }
    $t;
}

1;
