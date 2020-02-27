=pod
Lenio - Web-based Facilities Management Software
Copyright (C) 2016 Ctrl O Ltd

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

package Lenio::Calendar;

use Log::Report;
use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
use MooX::Types::MooseLike::DateTime qw/DateAndTime/;

has schema => (
    is       => 'ro',
    required => 1,
);

has from => (
    is  => 'ro',
    isa => DateAndTime,
);

has to => (
    is  => 'ro',
    isa => DateAndTime,
);

has dateformat => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

# Allow override of today for tests
has today => (
    is      => 'ro',
    isa     => DateAndTime,
    default => sub { DateTime->now },
);

has site => (
    is  => 'ro',
);

has login => (
    is  => 'ro',
);

has task_summary => (
    is  => 'lazy',
    isa => ArrayRef,
);

sub _build_task_summary
{   my $self = shift;
    my %options = (
        site_id => $self->site->id,
    );
    $options{global} = 1 if $self->login->is_admin;
    [$self->schema->resultset('Task')->summary(%options, onlysite => 1)];
}

# The task summary before the start date. This is used to find out
# the previous completed task dates, to fill in missing tasks.
has task_summary_previous => (
    is  => 'lazy',
    isa => ArrayRef,
);

sub _build_task_summary_previous
{   my $self = shift;
    my %options = (
        to      => $self->from,
        site_id => $self->site->id,
    );
    $options{global} = 1 if $self->login->is_admin;
    [$self->schema->resultset('Task')->summary(%options, onlysite => 1)];
}

has ticket_summary => (
    is  => 'lazy',
    isa => ArrayRef,
);

sub _build_ticket_summary
{   my $self = shift;
    [
        $self->schema->resultset('Ticket')->summary(
            site_id => $self->site->id,
            from    => $self->from,
            to      => $self->to,
            login   => $self->login,
        )
    ];
}

sub tasks
{   my $self = shift;

    my @calendar1; my @calendar2;

    my $planned;

    my $done; my $lastcomp;
    # First add all the tickets in this time period. 
    foreach my $ticket (@{$self->ticket_summary})
    {
        my $task_id = $ticket->task_id;
        push @calendar1, $self->_cal_item(
            name        => $ticket->name,
            description => $ticket->description,
            task_id     => $task_id,
            ticket_id   => $ticket->id,
            completed   => $ticket->completed,
            planned     => $ticket->planned,
            provisional => $ticket->provisional,
        );
        if ($task_id)
        {
            # Take the completed date if it exists, otherwise take the planned
            # date, otherwise take the provisional date. Future items and
            # warnings will be mapped out from this. If the planned date is in
            # the past, however, ignore it and plonk any overdue dates wherever
            # they would have been (otherwise they won't be shown)
            my $completed_planned = $ticket->completed;
            $completed_planned ||= $ticket->planned
                if $ticket->planned && $ticket->planned > $self->today;
            $completed_planned ||= $ticket->provisional
                if $ticket->provisional && $ticket->provisional > $self->today;
            $completed_planned or next;
            $done->{$task_id}->{$completed_planned} = $completed_planned;
            $lastcomp->{$task_id} = $ticket->completed
                if $ticket->completed && (!$lastcomp->{$task_id} || DateTime->compare($lastcomp->{$task_id}, $ticket->completed) < 0);
        }
    }

    foreach my $task (@{$self->task_summary_previous})
    {
        my $last_completed = $task->last_completed || $lastcomp->{$task->id}
            or next;
        # Take the last completed date, and keep on adding its due dates
        # until we pass the end of the period.
        my $period_unit = $task->period_unit or next;
        $task->period_qty
            or panic "period_qty is zero - will cause infinite loop";
        $period_unit .= "s";

        # Last time this task was completed
        my $date = $last_completed->clone;

        while (DateTime->compare($date, $self->to) < 0)
        {
            my %item = (
                name         => $task->name,
                description  => $task->description,
                task_id      => $task->id,
                due          => $date->clone,
                next_planned => $task->next_planned,
            );
            push @calendar2, $self->_cal_item(%item)
                if !$done->{$task->id}->{$date} && DateTime->compare($date, $self->from) >= 0; # Could be before current range

            # Calculate what the date should be for the next loop. Normally
            # this will be the date we've just been working with, plus the
            # period until the next time its due. However. we might have
            # completed tickets before then, in which case we should use
            # those to "reset" the counter.
            my @interim = grep {
                $_ > $date
                && $date->clone->add($period_unit => $task->period_qty) > $_
            } values %{$done->{$task->id}};
            if (@interim)
            {
                my $int = pop @interim;
                $date = $int->clone;
            }
            else {
                $date->add($period_unit => $task->period_qty);
            }
        }
    }
    (@calendar1, @calendar2);
}

sub _round_to_day
{   shift->clone->set(hour => 0, minute => 0, second => 0);
}

sub checks
{   my $self = shift;

    my @calendar;

    my @done = $self->schema->resultset('CheckDone')->summary(
        from    => $self->from,
        to      => $self->to,
        site_id => $self->site->id,
    );

    # First fill in all the ones that have actually been done.
    # We also interpolate between when there is a gap.
    my $previous; my $last_id;
    foreach my $check (@done)
    {
        $previous  = undef if !$last_id || $last_id != $check->site_task_id;
        my $qty    = $check->site_task->task->period_qty;
        my $unit   = $check->site_task->task->period_unit."s";
        my $status = $check->comment =~ /\S/
                   ? 'check-comment'
                   : 'check-'.$check->status;

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
                    id          => 'check'.$check->site_task->task->id,
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
            while (DateTime->compare($first, $self->from) >= 0)
            {
                my $count = $self->schema->resultset('CheckDone')->search({
                    site_task_id => $check->site_task_id,
                    datetime     => { '<', $self->schema->storage->datetime_parser->format_datetime($self->from) },
                })->count;
                my $clone = $first->clone;
                $clone->add( days => 1 )
                    if $unit eq 'months' && $clone->day_of_week == 7;
                $clone->add( days => 2 )
                    if $unit eq 'months' && $clone->day_of_week == 6;
                push @calendar, {
                    id          => 'check'.$check->site_task->task->id,
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
            id          => 'check'.$check->site_task->task->id,
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

    my @site_checks = $self->schema->resultset('Task')->site_checks($self->site->id);

    # Now take the very last completed one, and carry on filling
    # out the subsequent ones required.
    foreach my $check (@site_checks)
    {
        my $dtf  = $self->schema->storage->datetime_parser;

        my ($done) = $self->schema->resultset('CheckDone')->search({
            'task.id'           => $check->id,
            'site_task.site_id' => $self->site->id,
            'me.datetime'       => { '<=' => $dtf->format_datetime($self->to) },
        },{
            'prefetch' => { 'site_task' => 'task' },
            '+select'  => { max => 'me.datetime', -as => 'last_done' },
            '+as'      => 'last_done',
        })->all;

        my $ld = $done->get_column('last_done');
        my $qty  = $check->period_qty;
        my $unit = $check->period_unit."s";
        # If not ever done, start it off from today (take periodicity away, as is added straight back on)
        my $last_done = $ld
                      ? $self->schema->storage->datetime_parser->parse_datetime($ld)
                      : $self->today->clone->subtract( $unit => $qty);
        while (DateTime->compare($self->to, $last_done) >= 0)
        {
            # Keep adding until end of this range.
            $last_done->add( $unit => $qty );
            my $clone = $last_done->clone;
            $clone->add( days => 1 )
                if $unit eq 'months' && $clone->day_of_week == 7;
            $clone->add( days => 2 )
                if $unit eq 'months' && $clone->day_of_week == 6;
            next if (DateTime->compare($self->from, $clone) > 0); # Last done before this range
            my $status
                = DateTime->compare($self->today, $clone) > 0
                ? 'check-notdone'
                : $qty == 1 && $unit eq 'days'
                ? 'check-due-daily'
                : 'check-due';
            push @calendar, {
                id          => 'check'.$check->id,
                title       => $check->name,
                url         => "/check/".$check->id,
                start       => _round_to_day($clone)->epoch * 1000,
                end         => _round_to_day($clone)->epoch * 1000,
                class       => $status,
            } if DateTime->compare($self->to, $clone) > 0 && $clone->day_of_week < 6; # Not weekend
        }
    }
    @calendar;
}

sub _cal_item
{   my ($self, %item) = @_;

    # Only show planned where the ticket hasn't been completed.
    return unless $item{completed} || $item{planned} || $item{provisional} || $item{due};

    my $id  = $item{ticket_id}
            ? "ticket$item{ticket_id}"
            : "task$item{task_id}";
    my $url = $item{ticket_id}
            ? "/ticket/$item{ticket_id}"
            : "/ticket/0?task_id=$item{task_id}&site_id=".$self->site->id."&date=".$item{due}->ymd('-');

    my $title = $item{name};
    my $t = {
        id        => $id,
        title     => $title,
        url       => $url,
    };

    if ( $item{due} ) {
        if ( DateTime->compare( $item{due}, $self->today ) < 0)
        {
            $t->{class} = 'event-important';
            # Is it planned in for a future date?
            $t->{title} .= " (planned for ".$item{next_planned}->strftime($self->dateformat).")"
                if $item{next_planned} && $item{next_planned} > $self->today && $item{next_planned} > $item{due};
        }
        else {
            $t->{class} = 'event-warning';
        }
        $t->{start} = $item{due}->epoch * 1000;
        $t->{end}   = $item{due}->epoch * 1000;
    }
    else {
        if ( $item{completed} ) {
            $t->{class} = 'event-success';
            $t->{start} = $item{completed}->epoch * 1000;
            $t->{end}   = $item{completed}->epoch * 1000;
        }
        elsif ( $item{planned} ) {
            $t->{class} = $item{task_id} ? 'event-info' : 'event-special';
            $t->{start} = $item{planned}->epoch * 1000;
            $t->{end}   = $item{planned}->epoch * 1000;
        }
        else {
            $t->{class} = $item{task_id} ? 'event-info' : 'event-special';
            $t->{start} = $item{provisional}->epoch * 1000;
            $t->{end}   = $item{provisional}->epoch * 1000;
        }

    }
    $t;
}

1;
