use utf8;
package Lenio::Schema::Result::Org;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Org

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

=head1 TABLE: C<org>

=cut

__PACKAGE__->table("org");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 fyfrom

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "fyfrom",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_UNIQUE>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("name_UNIQUE", ["name"]);

=head1 RELATIONS

=head2 event_orgs

Type: has_many

Related object: L<Lenio::Schema::Result::EventOrg>

=cut

__PACKAGE__->has_many(
  "event_orgs",
  "Lenio::Schema::Result::EventOrg",
  { "foreign.org_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_orgs

Type: has_many

Related object: L<Lenio::Schema::Result::LoginOrg>

=cut

__PACKAGE__->has_many(
  "login_orgs",
  "Lenio::Schema::Result::LoginOrg",
  { "foreign.org_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 sites

Type: has_many

Related object: L<Lenio::Schema::Result::Site>

=cut

__PACKAGE__->has_many(
  "sites",
  "Lenio::Schema::Result::Site",
  { "foreign.org_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2014-02-20 00:04:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8ywD82OYbQOCY0mqWY5ehg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
