use utf8;
package Lenio::Schema::Result::Ticket;

use Log::Report;

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

__PACKAGE__->load_components("InflateColumn::DateTime", "+Lenio::DBIC");

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

=head2 created_by

  data_type: 'integer'
  is_foreign_key: 1
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

=head2 contractor_invoice

  data_type: 'text'
  is_nullable: 1

=head2 invoice_sent

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 actionee

  data_type: 'varchar'
  is_nullable: 1
  size: 16

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "created_at",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "provisional",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "planned",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "completed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "contractor_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "task_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "site_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "cost_planned",
  { data_type => "decimal", is_nullable => 1, size => [10, 2] },
  "cost_actual",
  { data_type => "decimal", is_nullable => 1, size => [10, 2] },
  "local_only",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "report_received",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "contractor_invoice",
  { data_type => "text", is_nullable => 1 },
  "invoice_sent",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "actionee",
  { data_type => "varchar", is_nullable => 1, size => 16 },
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

__PACKAGE__->belongs_to(
  "site",
  "Lenio::Schema::Result::Site",
  { id => "site_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

__PACKAGE__->belongs_to(
  "task",
  "Lenio::Schema::Result::Task",
  { id => "task_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 created_by

Type: belongs_to

Related object: L<Lenio::Schema::Result:Login>

=cut

__PACKAGE__->belongs_to(
  "created_by",
  "Lenio::Schema::Result::Login",
  { id => "created_by" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 invoice

Type: has_one

Related object: L<Lenio::Schema::Result::Invoice>

=cut

__PACKAGE__->might_have(
  "invoice",
  "Lenio::Schema::Result::Invoice",
  { "foreign.ticket_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub before_delete
{   my $self = shift;
    $self->invoice
        and error __x"Unable to delete ticket as it has an attached invoice (number {id}). Please delete the invoice first before deleting this ticket.",
            id => $self->invoice->id;
}

sub validate {
    my $self = shift;
    return if !$self->actionee;
    $self->actionee =~ /^(external|local|with_site)$/
        or error __x"Invalid actionee {actionee}", actionee => $self->actionee;
}

1;
