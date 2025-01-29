use Test::More; # tests => 1;
use strict;
use warnings;

use Log::Report;

use lib 't/lib';
use Test::Lenio::SeedData;

my $seed_data = Test::Lenio::SeedData->new;
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
})->delete;

is( _strike($schema, $site), 1, 'One task struck out after removal');

# Raise a ticket on the struck out item and check still struck out
$schema->resultset('Ticket')->create({
    name        => $task->name,
    description => $task->description,
    local_only  => 0,
    task_id     => $task->id,
    site_id     => $site->id
});

is( _strike($schema, $site), 1, 'Task still struck out with ticket against it');

# Local tasks
my $local = $schema->resultset('Task')->new({
    global      => 0,
    name        => 'Local 1',
    description => 'Local 1',
    period_qty  => 1,
    period_unit => 'month',
});
$local->set_site_id($site->id);
$local->insert;

is( $schema->resultset('Task')->summary(site_id => $site->id, onlysite => 1, global => 0), 1, 'One local task in summary' );

my $site2 = $schema->resultset('Site')->create({
    name   => 'Site 2',
    org_id => $seed_data->org->id,
});

is( $schema->resultset('Task')->summary(site_id => $site2->id, onlysite => 1, global => 0), 0, 'No local tasks for second site' );

done_testing();

sub _strike
{   my ($schema, $site) = @_;
    grep { $_->strike } $schema->resultset('Task')->summary(site_id => $site->id, global => 1);
}
