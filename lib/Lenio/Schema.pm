use utf8;
package Lenio::Schema;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;

our $VERSION = 21;

sub resultset
{   my $self = shift;
    my $rs = $self->next::method(@_);

    # Is this the site table itself?
    return $rs->search_rs({ 'me.deleted' => undef })
        if $rs->result_source->name eq 'org';

    # Otherwise add a site_id search if applicable
    return $rs unless $rs->result_source->has_column('org_id');
    $rs->search_rs({ 'org.deleted' => undef }, { join => 'org' });
}

1;
