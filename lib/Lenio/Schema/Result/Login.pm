use utf8;
package Lenio::Schema::Result::Login;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Login

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

=head1 TABLE: C<login>

=cut

__PACKAGE__->table("login");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 firstname

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 surname

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 password

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 is_admin

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 pwdreset

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 email_comment

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 email_ticket

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 deleted

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "firstname",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "surname",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "is_admin",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "pwdreset",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "email_comment",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "email_ticket",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "deleted",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 checks_done

Type: has_many

Related object: L<Lenio::Schema::Result::CheckDone>

=cut

__PACKAGE__->has_many(
  "checks_done",
  "Lenio::Schema::Result::CheckDone",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 comments

Type: has_many

Related object: L<Lenio::Schema::Result::Comment>

=cut

__PACKAGE__->has_many(
  "comments",
  "Lenio::Schema::Result::Comment",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_notices

Type: has_many

Related object: L<Lenio::Schema::Result::LoginNotice>

=cut

__PACKAGE__->has_many(
  "login_notices",
  "Lenio::Schema::Result::LoginNotice",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_orgs

Type: has_many

Related object: L<Lenio::Schema::Result::LoginOrg>

=cut

__PACKAGE__->has_many(
  "login_orgs",
  "Lenio::Schema::Result::LoginOrg",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_permissions

Type: has_many

Related object: L<Lenio::Schema::Result::LoginPermission>

=cut

__PACKAGE__->has_many(
  "login_permissions",
  "Lenio::Schema::Result::LoginPermission",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 site_checks_done

Type: has_many

Related object: L<Lenio::Schema::Result::SiteCheckDone>

=cut

__PACKAGE__->has_many(
  "site_checks_done",
  "Lenio::Schema::Result::SiteCheckDone",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-08 16:10:26
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8n+cV6tIA1Tvfv/bt3ZzSg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
