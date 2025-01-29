use utf8;
package Lenio::Schema::Result::Contractor;

use Log::Report;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Contractor

=cut

use strict;
use warnings;

use DateTime;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "+Lenio::DBIC");

=head1 TABLE: C<contractor>

=cut

__PACKAGE__->table("contractor");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
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

=head2 tickets

Type: has_many

Related object: L<Lenio::Schema::Result::Ticket>

=cut

__PACKAGE__->has_many(
  "tickets",
  "Lenio::Schema::Result::Ticket",
  { "foreign.contractor_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

sub delete_contractor
{   my $self = shift;
    $self->update({ deleted => DateTime->now });
}

sub validate {
    my $self = shift;
    error __"Please enter a name for the contractor" unless $self->name;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
