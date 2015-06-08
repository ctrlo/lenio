use utf8;
package Lenio::Schema::Result::LoginNotice;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::LoginNotice

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

=head1 TABLE: C<login_notice>

=cut

__PACKAGE__->table("login_notice");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 notice_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 login_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "notice_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "login_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

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

=head2 notice

Type: belongs_to

Related object: L<Lenio::Schema::Result::Notice>

=cut

__PACKAGE__->belongs_to(
  "notice",
  "Lenio::Schema::Result::Notice",
  { id => "notice_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-08 13:50:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:NqcvKlKFWVYQwNHchw6QdA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
