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
use Text::Trim;
use Ouch;

use Lenio::Schema;
use Lenio::FY;

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
    my $tasks   = $task_rs->search($search, { bind => [$site] });

    my @tasks;
    my $dtf = schema->storage->datetime_parser;
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
            # Work out date to take costs from (ie the financial year)
            my $fy = Lenio::FY->new($site, $args->{fy});

            my $c = rset('Ticket')->search(
                {
                    'site_task.task_id' => $task->id,
                    site_id             => $site,
                    completed           => {
                        -between => [
                            $dtf->format_datetime($fy->costfrom),
                            $dtf->format_datetime($fy->costto),
                        ],
                    },
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
    my $t = rset('Task')->find($task->{id})
        or ouch 'badid', "Unable to find the specified ID";
    $t->update($task)
        or ouch 'dbfail', "There was a database error when updating the task";
}

sub overdue($;$)
{   my ($self, $site, $args) = @_;
    my $task_rs = rset('Task');
    my @intervals = ('year', 'month', 'week', 'day');

    my @tasks;
    foreach my $interval (@intervals)
    {
        my $search =         {
            'period_unit'      => $interval,
        };
        $search->{global} = 1 unless $args->{local};
        my $s = ref $site eq 'ARRAY' ? [ map { $_->id } @$site ] : $site;
        $search->{'site.id'} = $s if $s;

        @tasks = (@tasks, $task_rs->search($search
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
                                             , { '<', \"DATE_SUB(NOW(), INTERVAL period_qty $interval)" }
                                             ] }
            }
        ));

    }
    @tasks;
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
