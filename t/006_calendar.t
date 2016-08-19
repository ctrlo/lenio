use Test::More; # tests => 1;
use strict;
use warnings;

use DateTime;
use DateTime::Format::Strptime;
use Lenio::Calendar;
use Log::Report;


use t::lib::SeedData;

sub _calendar; sub _to_dt;

my $today = DateTime->new(
    year  => 2016,
    month => 8,
    day   => 14,
);

my @tests = (
    {
        # Items completed month before, none this month
        items   => 6,
        classes => 'event-important event-important event-important event-warning event-warning event-warning',
        tickets => [
            {
                task_id   => 1,
                completed => '2016-07-05',
            }, {
                task_id   => 2,
                completed => '2016-07-05',
            },
        ],
        dates => [
            task1 => _to_dt('2016-08-02'),
            task2 => _to_dt('2016-08-05'),
            task1 => _to_dt('2016-08-09'),
            task1 => _to_dt('2016-08-16'),
            task1 => _to_dt('2016-08-23'),
            task1 => _to_dt('2016-08-30'),
        ],
    },
    {
        # Item completed first time this month, but one missed at beginning
        items   => 5,
        classes => 'event-important event-success event-info event-warning event-warning',
        tickets => [
            {
                task_id   => 1,
                completed => '2016-08-09',
            },
            {
                task_id   => 1,
                planned   => '2016-08-16',
            },
            {
                task_id   => 2,
                completed => '2016-07-05',
            },
        ],
        dates => [
            task2   => _to_dt('2016-08-05'),
            ticket1 => _to_dt('2016-08-09'),
            ticket2 => _to_dt('2016-08-16'),
            task1   => _to_dt('2016-08-23'),
            task1   => _to_dt('2016-08-30'),
        ],
    },
    {
        # Only one item completed, other not done at all
        items   => 4,
        classes => 'event-success event-success event-info event-warning',
        tickets => [
            {
                task_id   => 1,
                completed => '2016-08-09',
            },
            {
                task_id   => 1,
                completed => '2016-08-13',
            },
            {
                task_id   => 1,
                planned   => '2016-08-20',
            },
        ],
        dates => [
            ticket1 => _to_dt('2016-08-09'),
            ticket2 => _to_dt('2016-08-13'),
            ticket3 => _to_dt('2016-08-20'),
            task1   => _to_dt('2016-08-27'),
        ],
    },
    {
        # Items done out of normal cycle
        items   => 5,
        classes => 'event-important event-success event-success event-info event-warning',
        tickets => [
            {
                task_id   => 1,
                completed => '2016-07-15',
            },
            {
                task_id   => 1,
                completed => '2016-08-09',
            },
            {
                task_id   => 1,
                completed => '2016-08-13',
            },
            {
                task_id   => 1,
                planned   => '2016-08-20',
            },
        ],
        dates => [
            task1   => _to_dt('2016-08-05'),
            ticket2 => _to_dt('2016-08-09'),
            ticket3 => _to_dt('2016-08-13'),
            ticket4 => _to_dt('2016-08-20'),
            task1   => _to_dt('2016-08-27'),
        ],
    },
    {
        # One task completed previous month
        items   => 1,
        classes => 'event-warning',
        tickets => [
            {
                task_id   => 2,
                completed => '2016-07-20',
            },
        ],
        dates => [
            task2   => _to_dt('2016-08-20'),
        ],
    },
    {
        # Check tasks only show within month selected, not days either side
        items   => 31,
        tickets => [
            {
                task_id   => 3,
                completed => '2016-07-31',
            },
        ],
    },
);

foreach my $test (@tests)
{
    my $seed_data = t::lib::SeedData->new;
    my $schema    = $seed_data->schema;
    my $site      = $seed_data->site;
    my $tasks     = $seed_data->tasks;

    is( _calendar($seed_data)->tasks, 0, "Nothing to show on calendar for no tickets" );

    # Add some tickets in the past. The tasks will show as overdue this month.
    foreach my $ticket (@{$test->{tickets}})
    {
        my ($task) = grep { $_->id == $ticket->{task_id} } @$tasks;
        my $ticket = $schema->resultset('Ticket')->create({
            name        => $task->name,
            description => $task->description,
            planned     => $ticket->{planned},
            completed   => $ticket->{completed},
            local_only  => $task->global ? 0 : 1,
            site_task   => {
                task_id => $task->id,
                site_id => $site->id,
            },
        });
    }

    my @items = sort { $a->{start} <=> $b->{start} } _calendar($seed_data)->tasks;

    is( @items, $test->{items}, "Correct number of items on calendar for all overdue" );

    my @class = map { $_->{class} } @items;

    is( "@class", $test->{classes}, "Correct classes on calendar for all overdue" )
        if exists $test->{classes};

    exists $test->{dates}
        or next;
    my @dates = @{$test->{dates}};
    foreach my $item (@items)
    {
        my $id = shift @dates;
        my $dt = shift @dates;
        is($id, $item->{id}, "Correct ID for task item");
        is($dt && $dt->epoch * 1000, $item->{start}, "Correct start for task item")
    }
}

# Site check tests
@tests = (
    {
        # Weekly task with various statuses, starting on first day of month
        count_begin => 0, # All at weekend
        items       => 5,
        classes     => 'check-partdone check-notdone check-due check-due check-due',
        checks_done => [
            {
                check_name => 'Check 1',
                datetime => _to_dt('2016-08-01'),
                items    => [
                    {
                        id     => 1,
                        status => 1,
                    },
                ],
            },
        ],
        dates => [
            check4 => _to_dt('2016-08-01'),
            check4 => _to_dt('2016-08-08'),
            check4 => _to_dt('2016-08-15'),
            check4 => _to_dt('2016-08-22'),
            check4 => _to_dt('2016-08-29'),
        ],
    },
    {
        # Weekly task with more statuses
        count_begin => 0, # All at weekend
        items       => 3,
        classes     => 'check-done check-due check-due',
        checks_done => [
            {
                check_name => 'Check 1',
                datetime => _to_dt('2016-08-17'),
                items    => [
                    {
                        id     => 1,
                        status => 1,
                    },
                    {
                        id     => 2,
                        status => 1,
                    },
                ],
            },
        ],
        dates => [
            check4 => _to_dt('2016-08-17'),
            check4 => _to_dt('2016-08-24'),
            check4 => _to_dt('2016-08-31'),
        ],
    },
    {
        # Monthly, ensure moved to Monday when falling at weekend
        count_begin => 1,
        items       => 1,
        classes     => 'check-due',
        checks_done => [
            {
                check_name => 'Check 3',
                datetime => _to_dt('2016-07-20'),
                items    => [
                    {
                        id     => 1,
                        status => 1,
                    },
                ],
            },
        ],
        dates => [
            check4 => _to_dt('2016-08-22'),
        ],
    },
    {
        # Every day, shouldn't appear at weekends
        count_begin => 13,
        items       => 23,
        checks_done => [
            {
                check_name => 'Check 2',
                datetime => _to_dt('2016-08-01'),
                items    => [
                    {
                        id     => 1,
                        status => 1,
                    },
                ],
            },
        ],
    },
);

foreach my $test (@tests)
{
    my @select_checks = map { $_->{check_name} } @{$test->{checks_done}};
    my $seed_data = t::lib::SeedData->new(select_checks => [@select_checks]);
    my $schema    = $seed_data->schema;
    my $site      = $seed_data->site;
    my $checks    = $seed_data->checks;

    is( _calendar($seed_data)->checks, $test->{count_begin}, "Correct number of checks on calendar for no tickets" );

    foreach my $check_done (@{$test->{checks_done}})
    {
        my ($check) = grep { $_->name eq $check_done->{check_name} } @$checks;

        my $site_task_id = $schema->resultset('SiteTask')->search({
            task_id => $check->id,
            site_id => $site->id,
        })->next->id;

        my $cd = $schema->resultset('CheckDone')->create({
            datetime     => $check_done->{datetime},
            comment      => '',
            site_task_id => $site_task_id,
            login_id     => $seed_data->login->id,
        });

        foreach my $cid (@{$check_done->{items}})
        {
            $schema->resultset('CheckItemDone')->create({
                check_item_id => $cid->{id},
                check_done_id => $cd->id,
                status        => $cid->{status},
            });
        }
    }

    my @items = sort { $a->{start} <=> $b->{start} } _calendar($seed_data)->checks;

    is( @items, $test->{items}, "Correct number of items on calendar for all overdue" );

    my @class = map { $_->{class} } @items;

    is( "@class", $test->{classes}, "Correct classes on calendar for all overdue" )
        if exists $test->{classes};

    exists $test->{dates}
        or next;
    my @dates = @{$test->{dates}};
    foreach my $item (@items)
    {
        my $id = shift @dates;
        my $dt = shift @dates;
        is($item->{id}, $id, "Correct ID for task item");
        is($item->{start}, $dt && $dt->epoch * 1000, "Correct start for task item")
    }
}

done_testing();

sub _calendar
{   my $seed_data = shift;
    # Take the calendar for this month
    my $firstday = $today->clone->truncate(to => 'month');
    my $lastday  = $firstday->clone->add(months => 1);
    my $login    = $seed_data->login;
    $login->update({ is_admin => 1 });
    Lenio::Calendar->new(
        from   => $firstday,
        to     => $lastday,
        today  => $today,
        site   => $seed_data->site,
        login  => $login,
        schema => $seed_data->schema,
    );
}

sub _to_dt
{   my $parser = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
         time_zone => 'UTC',
    );
    $parser->parse_datetime(shift);
}