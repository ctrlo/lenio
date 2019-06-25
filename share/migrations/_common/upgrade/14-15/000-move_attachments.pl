use strict;
use warnings;

use DateTime;
use DBIx::Class::Migration::RunScript;
use FindBin;
use JSON qw(encode_json);
use Log::Report;

use lib "$FindBin::Bin/../lib";

use File::Basename qw(basename);
use Config::Any    ();

my $config_fn = basename $0 . '/config.yml';
my $lib       = "$FindBin::Bin/../lib";

my $config    = Config::Any->load_files({
    files   => [ $config_fn ],
    use_ext => 1,
});

my $conf = $config->[0]{'config.yml'}
    or die "configuration file structure changed.";

migrate {
    my $schema = shift->schema;
    # dbic_connect_attrs is ignored, so quote_names needs to be forced
    $schema->storage->connect_info(
        [sub {$schema->storage->dbh}, { quote_names => 1 }]
    );

    my $config = Lenio::Config->instance(config => $conf);

    foreach my $attach_id ($schema->resultset('Attach')->get_column('id')->all)
    {
        my $attach = $schema->resultset('Attach')->find($attach_id);
        my $target = Lenio::Schema::Result::Attach::idtofile($attach->id);
        $target->dir->mkpath;
        $target->spew(iomode => '>:raw', $attach->content);
    }
};
