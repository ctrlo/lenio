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

    foreach my $ticket ($schema->resultset('Ticket')->all)
    {
        $schema->resultset('SiteTask')->create({
            site_id   => $ticket->site_id,
            task_id   => $ticket->task_id,
            ticket_id => $ticket->id,
        });
    }
};
