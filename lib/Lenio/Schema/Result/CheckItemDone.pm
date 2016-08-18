use utf8;
package Lenio::Schema::Result::CheckItemDone;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::CheckItemDone

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<check_item_done>

=cut

__PACKAGE__->table("check_item_done");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 check_item_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 check_done_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 status

  data_type: 'smallint'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "check_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "check_done_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status",
  { data_type => "smallint", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

__PACKAGE__->add_unique_constraint("check_item_done_UNIQUE", ["check_item_id", "check_done_id"]);

=head1 RELATIONS

=head2 check_done

Type: belongs_to

Related object: L<Lenio::Schema::Result::CheckDone>

=cut

__PACKAGE__->belongs_to(
  "check_done",
  "Lenio::Schema::Result::CheckDone",
  { id => "check_done_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);

=head2 check_item

Type: belongs_to

Related object: L<Lenio::Schema::Result::CheckItem>

=cut

__PACKAGE__->belongs_to(
  "check_item",
  "Lenio::Schema::Result::CheckItem",
  { id => "check_item_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-08 13:50:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5hfbk2Vqq+jvlNU9d/uv2Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
