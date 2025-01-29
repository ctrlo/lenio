use Test::More; # tests => 1;
use strict;
use warnings;

use Test::MockTime qw(set_fixed_time restore_time); # Load before DateTime
use DateTime;
use DateTime::Format::Strptime;
use Log::Report;

set_fixed_time('10/10/2016 01:00:00', '%m/%d/%Y %H:%M:%S');

use lib 't/lib';
use Test::Lenio::SeedData;

sub _calendar; sub _to_dt;

my @tests = (
    {
        tasks => [
            {
                cost_planned => {
                    2015 => 20,
                    2016 => 12,
                },
                cost_actual  => {
                    2015 => 19,
                    2016 => 15,
                },
                last_completed => '2016-07-06',
                tickets => [
                    {
                        task_id      => 1,
                        completed    => '2015-06-16',
                        cost_planned => 20,
                        cost_actual  => 19,
                    }, {
                        task_id      => 1,
                        completed    => '2016-07-05',
                        cost_planned => 2,
                        cost_actual  => 6,
                    }, {
                        task_id      => 1,
                        completed    => '2016-07-06',
                        cost_planned => 10,
                        cost_actual  => 9,
                    },
                ],
            },
            {
                cost_planned => {
                    2015 => undef,
                    2016 => 10,
                },
                cost_actual  => {
                    2015 => undef,
                    2016 => 25,
                },
                last_completed => '2016-07-08',
                tickets => [
                    {
                        task_id      => 2,
                        completed    => '2016-07-07',
                        cost_planned => 5,
                        cost_actual  => 10,
                    }, {
                        task_id      => 2,
                        completed    => '2016-07-08',
                        cost_planned => 5,
                        cost_actual  => 15,
                    },
                ],
            },
        ]
    },
    {
        tasks => [
            {
                cost_planned => {
                    2015 => undef,
                    2016 => 26,
                },
                cost_actual  => {
                    2015 => undef,
                    2016 => undef,
                },
                last_completed => undef,
                tickets => [
                    {
                        task_id      => 1,
                        planned      => '2016-07-07',
                        cost_planned => 12,
                        cost_actual  => undef,
                    }, {
                        task_id      => 1,
                        cost_planned => 14,
                        cost_actual  => undef,
                    },
                ],
            },
        ],
    },
    {
        tasks => [
            {
                cost_planned => {
                    2015 => undef,
                    2016 => 14,
                },
                cost_actual  => {
                    2015 => 15,
                    2016 => undef,
                },
                last_completed => '2015-07-07',
                tickets => [
                    {
                        task_id      => 1,
                        completed    => '2015-07-07',
                        cost_planned => undef,
                        cost_actual  => 15,
                    }, {
                        task_id      => 1,
                        cost_planned => 14,
                    },
                ],
            },
        ],
    },
);

foreach my $test (@tests)
{
    my $seed_data = Test::Lenio::SeedData->new;
    my $schema    = $seed_data->schema;
    my $site      = $seed_data->site;
    my $tasks     = $seed_data->tasks;


    # Add some tickets in the past. The tasks will show as overdue this month.
    foreach my $task (@{$test->{tasks}})
    {
        foreach my $ticket (@{$task->{tickets}})
        {
            my ($task) = grep { $_->id == $ticket->{task_id} } @$tasks;
            my $ticket = $schema->resultset('Ticket')->create({
                name         => $task->name,
                description  => $task->description,
                planned      => $ticket->{planned},
                completed    => $ticket->{completed},
                cost_planned => $ticket->{cost_planned},
                cost_actual  => $ticket->{cost_actual},
                local_only   => $task->global ? 0 : 1,
                task_id      => $task->id,
                site_id      => $site->id,
            });
        }
    }

    my $task_completed = $schema->resultset('Task')->last_completed(site_id => $site->id, global => 1);

    foreach my $fy (qw/2015 2016/)
    {
        my @tasks = $schema->resultset('Task')->summary(site_id => $site->id, global => 1, fy => $fy);

        my $count = 0;
        foreach my $task (@tasks)
        {
            my $task_test = @{$test->{tasks}}[$count];
            is( $task->cost_planned, $task_test->{cost_planned}->{$fy}, "Correct planned cost for task ".$task->name." year $fy" );
            is( $task->cost_actual, $task_test->{cost_actual}->{$fy}, "Correct actual cost for task ".$task->name." year $fy" );
            is( $task_completed->{$task->id} && $task_completed->{$task->id}->ymd, $task_test->{last_completed}, "Last completed date correct for ".$task->name )
                if $fy == 2016;
            $count++;
        }
    }
}

done_testing();

sub _calendar
{   my $seed_data = shift;
    # Take the calendar for this month
    my $today = DateTime->new(
        year  => 2016,
        month => 8,
        day   => 14,
    );
    my $firstday = $today->clone->truncate(to => 'month');
    my $lastday  = $firstday->clone->add(months => 1)->subtract(days => 1);
    Lenio::Calendar->new(
        from   => $firstday,
        to     => $lastday,
        today  => $today,
        site   => $seed_data->site,
        login  => { is_admin => 1},
        schema => $seed_data->schema,
    );
}

sub _to_dt
{   my $parser = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
    );
    $parser->parse_datetime(shift);
}
