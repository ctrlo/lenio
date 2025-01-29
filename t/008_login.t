use Test::More; # tests => 1;
use strict;
use warnings;

use Log::Report;

use lib 't/lib';
use Test::Lenio::SeedData;

my $seed_data = Test::Lenio::SeedData->new;
my $schema    = $seed_data->schema;
my $login     = $seed_data->login;
my $site      = $seed_data->site;

ok( $login->has_site($site->id), "Initial login has access to initial site" );

my $org2  = $seed_data->org2;
my $site2 = $seed_data->site2;
my $login2 = $schema->resultset('Login')->create({
    username => 'XX',
    email    => 'XX',
    password => 'XX',
});
$login2->update_orgs($org2->id);

ok( $login->has_site($site->id), "Initial login still has access to initial site" );
ok( !$login->has_site($site2->id), "Initial login does not have access to second site" );
ok( $login2->has_site($site2->id), "Second login has access to second site" );

$login->update({ is_admin => 1 });

ok( $login->has_site($site2->id), "Initial login has access to second site when admin" );

my $task = $seed_data->tasks->[0];
my $site_task = $schema->resultset('SiteTask')->create({
    task_id   => $task->id,
    site_id   => $site->id,
});
ok( $login->has_site_task($site_task->id), "Initial login has access to site_task" );
ok( !$login2->has_site_task($site_task->id), "Second login does not have access to site_task" );

$login2->update({ is_admin => 1 });
ok( $login2->has_site_task($site_task->id), "Second login has access to site_task when admin" );

is( $login->sites, 2, "First login has 2 sites when admin" );

done_testing;
