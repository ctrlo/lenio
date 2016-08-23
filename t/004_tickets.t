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
            site_task    => {
                site_id => $site->id,
            },
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
            site_task    => {
                site_id => $site->id,
                task_id => $task->id,
            },
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

foreach my $task_tickets (0, 1, undef)
{
    foreach my $uncompleted_only (0, 1)
    {
        foreach my $fy (undef, 2015, 2016)
        {
            my $login = $seed_data->login;
            $login->update({ is_admin => 1 });
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

# Try and delete the ticket
# Check row numbers in database change as expected
my $task_count = $schema->resultset('Task')->count;
my $ticket_count = $schema->resultset('Ticket')->count;
my $site_task_count = $schema->resultset('SiteTask')->count;
try { $ticket->delete };
ok(!$@, "Failed to delete ticket. Exception: $@");
is($schema->resultset('Task')->count, $task_count, "Number of tasks remains same after ticket deletion");
is($schema->resultset('Ticket')->count, $ticket_count - 1, "Number of tickets goes down by one after deletion");
is($schema->resultset('SiteTask')->count, $site_task_count - 1, "Number of tickets goes down by one after deletion");

done_testing();
