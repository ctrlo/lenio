use utf8;
package Lenio::Schema::Result::CheckDone;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::CheckDone

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

=head1 TABLE: C<check_done>

=cut

__PACKAGE__->table("check_done");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 site_task_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 login_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 datetime

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 comment

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "site_task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "login_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "comment",
  { data_type => "text", is_nullable => 1 },
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
  { "foreign.check_done_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login

Type: belongs_to

Related object: L<Lenio::Schema::Result::Login>

=cut

__PACKAGE__->belongs_to(
  "login",
  "Lenio::Schema::Result::Login",
  { id => "login_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 site_task

Type: belongs_to

Related object: L<Lenio::Schema::Result::SiteTask>

=cut

__PACKAGE__->belongs_to(
  "site_task",
  "Lenio::Schema::Result::SiteTask",
  { id => "site_task_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-08 13:50:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZFxK/hMFnSajDuMquIcrzg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
