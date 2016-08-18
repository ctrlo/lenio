use Test::More; # tests => 1;
use strict;
use warnings;

use Log::Report;

use t::lib::SeedData;

my $seed_data = t::lib::SeedData->new;
my $tasks = $seed_data->tasks;
my $schema = $seed_data->schema;
my $task   = $tasks->[0];
my $site   = $seed_data->site;

is( @$tasks, 3, "Correct number of tasks created" );

# Check striking of tasks for site

is( _strike($schema, $site), 0, 'All tasks initially not struck-out' );

# Delete one
$schema->resultset('SiteTask')->search({
    task_id   => $task->id,
    site_id   => $site->id,
    ticket_id => undef,
})->delete;

is( _strike($schema, $site), 1, 'One task struck out after removal');

# Raise a ticket on the struck out item and check still struck out
$schema->resultset('Ticket')->create({
    name        => $task->name,
    description => $task->description,
    local_only  => 0,
    site_task   => {
        task_id => $task->id,
        site_id => $site->id
    },
});

is( _strike($schema, $site), 1, 'Task still struck out with ticket against it');

done_testing();

sub _strike
{   my ($schema, $site) = @_;
    grep { $_->strike } $schema->resultset('Task')->summary(site_id => $site->id, global => 1);
}
