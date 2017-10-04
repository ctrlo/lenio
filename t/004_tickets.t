use Test::More; # tests => 1;
use strict;
use warnings;

use DateTime;
use Log::Report;

use t::lib::SeedData;

my $seed_data   = t::lib::SeedData->new;
my $tasks       = $seed_data->tasks;
my $schema      = $seed_data->schema;
my $contractors = $seed_data->contractors;
my $site        = $seed_data->site;

my $contractor = $contractors->[0];
my $task       = $tasks->[0];

my @tickets = (
    {
        ticket => {
            name         => 'Reactive 1',
            description  => 'Rective 1 description',
            contractor   => $contractor,
            cost_planned => 10,
            cost_actual  => 20,
            local_only   => 0,
            planned      => '2011-10-10',
            site_id      => $site->id,
        },
    },
    {
        ticket => {
            name         => 'Reactive Local',
            description  => 'Rective local description',
            local_only   => 1,
            site_id      => $site->id,
        },
    },
    {
        ticket => {
            name         => $task->name,
            description  => $task->description,
            contractor   => $contractor,
            cost_planned => 10,
            cost_actual  => 20,
            local_only   => 0,
            planned      => '2011-10-10',
            site_id      => $site->id,
            task_id      => $task->id,
        },
    }
);

my $count;
foreach my $ticket (@tickets)
{
    foreach my $completed (0, 1)
    {
        $count++;
        $ticket->{ticket}->{completed} = '2015-10-10' if $completed;
        $schema->resultset('Ticket')->create($ticket->{ticket});
        is( $schema->resultset('Ticket')->count, $count, "Correct number of tickets in database table" );
    }
}

my $login = $seed_data->login;
$login->update({ is_admin => 1 });
foreach my $task_tickets (0, 1, undef)
{
    foreach my $uncompleted_only (0, 1)
    {
        foreach my $fy (undef, 2015, 2016)
        {
            my @summary = $schema->resultset('Ticket')->summary(
                login            => $login,
                site_id          => $site->id,
                uncompleted_only => $uncompleted_only,
                # task_id          => $task_id,
                task_tickets     => $task_tickets,
                fy               => $fy,
            );
            my $count = defined $task_tickets ? 1 : 2;
            $count = $count * 2 if !$uncompleted_only;
            if ($fy)
            {
                if ($uncompleted_only || $fy == 2016)
                {
                    $count = 0;
                }
                else {
                    $count = $count / 2;
                }
            }
            is( @summary, $count, "Correct number of tickets in summary" );
        }
    }
}

$schema->resultset('Ticket')->search({ completed => { '!=' => undef } })->delete;
# Tests to ensure correct number of tickets appear for admin/non-admin
# with global/local tickets/tasks
#
# First add a local task and associated ticket
my $task_local = $schema->resultset('Task')->new({
    global      => 0,
    name        => 'Local task',
    description => 'Local desc',
    period_qty  => 1,
    period_unit => 'day',
});
$task_local->set_site_id($site->id);
$task_local->insert;
my $ticket_local = $schema->resultset('Ticket')->create({
    name        => 'Local',
    description => 'Local',
    site_id     => $site->id,
    task_id     => $task_local->id,
});
# And one for another site
my $org2 = $schema->resultset('Org')->create({
    name => 'Org 2',
});
my $site2 = $schema->resultset('Site')->create({
    name   => 'Site 2',
    org_id => $org2->id,
});
my $task2 = $schema->resultset('Task')->new({
    global      => 1,
    name        => 'Task 2',
    description => 'Task 2',
    period_qty  => 1,
    period_unit => 'day',
});
$task2->set_site_id($site2->id);
$task2->insert;
my $ticket2 = $schema->resultset('Ticket')->create({
    name        => 'Task 2',
    description => 'Task 2',
    site_id     => $site2->id,
    task_id     => $task2->id,
});

foreach my $admin (0, 1)
{
    my $login = $seed_data->login;
    $login->update({ is_admin => $admin });
    foreach my $task_tickets (undef, 0, 1)
    {
        foreach my $task_id (undef, $task->id)
        {
            my @summary = $schema->resultset('Ticket')->summary(
                login            => $login,
                task_id          => $task_id,
                task_tickets     => $task_tickets,
            );
            # Count should always be the same, regardless of admin status:
            # - admin will see the ticket for site 2
            # - non-admin will see site 1 local ticket
            if (defined $task_tickets)
            {
                if ($task_tickets)
                {
                    if ($task_id)
                    {
                        is( @summary, 1, "Correct number of tickets in summary for viewing task ".$task->id." (admin $admin)" );
                    }
                    else {
                        is( @summary, 2, "Correct number of tickets in summary for viewing all task tickets (admin $admin)" );
                    }
                }
                else {
                    if ($task_id)
                    {
                        is( @summary, 1, "Correct number of tickets in summary for viewing task ".$task->id." (admin $admin)" );
                    }
                    else {
                        my $count = $admin ? 1 : 2;
                        is( @summary, $count, "Correct number of tickets in summary for viewing all tickets that are not task-related (admin $admin)" );
                    }
                }
            }
        }
    }
}

# General ticket tests
my $ticket = $schema->resultset('Ticket')->next;
# Add a comment
$schema->resultset('Comment')->create({
    text      => 'Comment',
    ticket_id => $ticket->id,
    login_id  => $seed_data->login->id,
    datetime  => DateTime->now,
});
# Add an attachment
$schema->resultset('Attach')->create({
    name        => "Filename.txt",
    ticket_id   => $ticket->id,
    content     => "File content",
    mimetype    => 'text/plain',
});

# Add an invoice before ticket deletion
my $invoice = $schema->resultset('Invoice')->create({
    description => 'Invoice description',
    number      => '1234',
    ticket_id   => $ticket->id,
    datetime    => DateTime->now,
});

# Try and delete the ticket with invoice attached first
try { $ticket->delete };
like($@, qr/Unable to delete ticket/, "Failed to delete ticket with invoice attached");

# Remove invoice and try again
$invoice->delete;
# Reload ticket to reflect invoice deletion
$ticket = $schema->resultset('Ticket')->find($ticket->id);

# Check row numbers in database change as expected
my $task_count = $schema->resultset('Task')->count;
my $ticket_count = $schema->resultset('Ticket')->count;
try { $ticket->delete };
ok(!$@, "Failed to delete ticket. Exception: $@");
is($schema->resultset('Task')->count, $task_count, "Number of tasks remains same after ticket deletion");
is($schema->resultset('Ticket')->count, $ticket_count - 1, "Number of tickets goes down by one after deletion");

done_testing();
