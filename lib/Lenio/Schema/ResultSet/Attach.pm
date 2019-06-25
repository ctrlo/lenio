package Lenio::Schema::ResultSet::Attach;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use Log::Report;

sub create_with_file
{   my ($self, $attach) = @_;
    my $guard = $self->result_source->schema->txn_scope_guard;
    my $upload = delete $attach->{upload};
    my $attach_rs = $self->create($attach);
    $attach_rs->update_file($upload);
    $guard->commit;
    return $attach_rs;
}

1;
