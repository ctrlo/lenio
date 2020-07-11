use utf8;
package Lenio::Schema::Result::Group;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

__PACKAGE__->mk_group_accessors('simple' => qw/set_site_ids/);

__PACKAGE__->table("group");

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->has_many(
  "site_groups",
  "Lenio::Schema::Result::SiteGroup",
  { "foreign.group_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub site_ids
{   my $self = shift;
    [ map $_->site_id, $self->site_groups ];
}

sub write
{   my $self = shift;
    my $schema = $self->result_source->schema;
    my $guard = $schema->txn_scope_guard;
    $self->update_or_insert;
    $schema->resultset('SiteGroup')->search({
        group_id => $self->id,
    })->delete;
    foreach my $site_id (@{$self->set_site_ids})
    {
        $schema->resultset('SiteGroup')->create({
            group_id => $self->id,
            site_id  => $site_id,
        });
    }
    $guard->commit;
}

sub has_site
{   my ($self, $site_id) = @_;
    $self->result_source->schema->resultset('SiteGroup')->search({
        site_id  => $site_id,
        group_id => $self->id,
    })->count;
}

1;
