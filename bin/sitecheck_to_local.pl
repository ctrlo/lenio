#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Dancer2;
use Dancer2::Plugin::DBIC;

my $guard = schema->txn_scope_guard;

# Move all site_checks from global to local
foreach my $task (
    schema->resultset('Task')->search(
        { site_check => 1 }
    )->all
)
{
    foreach my $site_task (
        schema->resultset('SiteTask')->search(
            {
                task_id => $task->id,
            }
        )->all
    )
    {
        my $local = schema->resultset('Task')->create({
            name        => $task->name,
            description => $task->description,
            period_unit => $task->period_unit,
            period_qty  => $task->period_qty,
            global      => 0,
            site_check  => 1,
        });
        $site_task->update({
            task_id => $local->id,
        });
        foreach my $check_item (
            schema->resultset('CheckItem')->search(
                {
                    task_id => $task->id,
                }
            )->all
        )
        {
            my $check_item_local = schema->resultset('CheckItem')->create({
                name    => $check_item->name,
                task_id => $local->id,
            });
            foreach my $check_done (
                schema->resultset('CheckDone')->search({
                    site_task_id => $site_task->id,
                })->all
            )
            {
                schema->resultset('CheckItemDone')->search({
                    check_item_id => $check_item->id,
                    check_done_id => $check_done->id,
                })->update({
                        check_item_id => $check_item_local->id,
                });
            }
        }
    }
    schema->resultset('CheckItem')->search({
        task_id => $task->id,
    })->delete;
    $task->delete;
}

$guard->commit;

