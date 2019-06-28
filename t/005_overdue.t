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

my $seed_data = t::lib::SeedData->new;
my $schema    = $seed_data->schema;
my $site      = $seed_data->site;
my $tasks     = $seed_data->tasks;

my @overdue = $schema->resultset('Task')->overdue(site_id => $site->id);
is( @overdue, 3, "All items overdue when no tickets raised" );

foreach my $task (@$tasks)
{
    my $ticket = $schema->resultset('Ticket')->create({
        name        => $task->name,
        description => $task->description,
        completed   => _to_dt('2016-07-01'),
        local_only  => $task->global ? 0 : 1,
        task_id     => $task->id,
        site_id     => $site->id,
    });
}

@overdue = $schema->resultset('Task')->overdue(site_id => $site->id);
is( @overdue, @$tasks, "Overdue item for all tasks when all tickets out of date" );

# Remove one item from site, check it disappears
$schema->resultset('SiteTask')->search({
    task_id   => $tasks->[0]->id,
    site_id   => $site->id,
})->delete;

is( $schema->resultset('Task')->overdue(site_id => $site->id), @$tasks - 1, "Overdue items reduce by one when task removed as item" );

# Add tickets to set task in date
foreach my $task (@$tasks)
{
    my $ticket = $schema->resultset('Ticket')->create({
        name        => $task->name,
        description => $task->description,
        completed   => DateTime->now, # Database query uses live date, not mock
        local_only  => $task->global ? 0 : 1,
        task_id     => $task->id,
        site_id     => $site->id,
    });
}

@overdue = $schema->resultset('Task')->overdue(site_id => $site->id);
is( @overdue, 0, "No overdue items when tasks in date" );

done_testing();

sub _to_dt
{   my $parser = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
    );
    $parser->parse_datetime(shift);
}
