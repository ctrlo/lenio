use utf8;
package Lenio::Schema::Result::CheckItem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::CheckItem

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

=head1 TABLE: C<check_item>

=cut

__PACKAGE__->table("check_item");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1
  size: 128

=head2 task_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 check_items_done

Type: has_many

Related object: L<Lenio::Schema::Result::CheckItemDone>

=cut

__PACKAGE__->has_many(
  "check_items_done",
  "Lenio::Schema::Result::CheckItemDone",
  { "foreign.check_item_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 1 },
);

=head2 task

Type: belongs_to

Related object: L<Lenio::Schema::Result::Task>

=cut

__PACKAGE__->belongs_to(
  "task",
  "Lenio::Schema::Result::Task",
  { id => "task_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-16 11:45:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ClLR3EwOK9xPduiv/lVS7Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
