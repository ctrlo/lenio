use strict;
use warnings;

use DateTime;
use DBIx::Class::Migration::RunScript;
use JSON qw(encode_json);
 
migrate {
    my $schema = shift->schema;
    # dbic_connect_attrs is ignored, so quote_names needs to be forced
    $schema->storage->connect_info(
        [sub {$schema->storage->dbh}, { quote_names => 1 }]
    );

    foreach my $site_task ($schema->resultset('SiteTask')->search({
        ticket_id => { '!=' => undef },
    })->all)
    {
        $schema->resultset('Ticket')->find($site_task->ticket_id)->update({
            site_id => $site_task->site_id,
            task_id => $site_task->task_id,
        });
        $site_task->delete;
    }
};
