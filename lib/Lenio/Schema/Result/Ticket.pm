use utf8;
package Lenio::Schema::Result::Ticket;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Ticket

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

=head1 TABLE: C<ticket>

=cut

__PACKAGE__->table("ticket");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 planned

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 completed

  data_type: 'date'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 contractor_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 cost_planned

  data_type: 'decimal'
  is_nullable: 1
  size: [10,2]

=head2 cost_actual

  data_type: 'decimal'
  is_nullable: 1
  size: [10,2]

=head2 local_only

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 report_received

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 invoice_sent

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "planned",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "completed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "contractor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "cost_planned",
  { data_type => "decimal", is_nullable => 1, size => [10, 2] },
  "cost_actual",
  { data_type => "decimal", is_nullable => 1, size => [10, 2] },
  "local_only",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "report_received",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "invoice_sent",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 attaches

Type: has_many

Related object: L<Lenio::Schema::Result::Attach>

=cut

__PACKAGE__->has_many(
  "attaches",
  "Lenio::Schema::Result::Attach",
  { "foreign.ticket_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 1 },
);

=head2 comments

Type: has_many

Related object: L<Lenio::Schema::Result::Comment>

=cut

__PACKAGE__->has_many(
  "comments",
  "Lenio::Schema::Result::Comment",
  { "foreign.ticket_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 1 },
);

=head2 contractor

Type: belongs_to

Related object: L<Lenio::Schema::Result::Contractor>

=cut

__PACKAGE__->belongs_to(
  "contractor",
  "Lenio::Schema::Result::Contractor",
  { id => "contractor_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 site_task

Type: might_have

Related object: L<Lenio::Schema::Result::SiteTask>

=cut

__PACKAGE__->might_have(
  "site_task",
  "Lenio::Schema::Result::SiteTask",
  { "foreign.ticket_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 1 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-09 10:25:25
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4nUUbU5VN4lI9K26qKpK/Q


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
