use utf8;
package Lenio::Schema::Result::Site;

use DateTime;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Site

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

=head1 TABLE: C<site>

=cut

__PACKAGE__->table("site");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=head2 org_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "org_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 org

Type: belongs_to

Related object: L<Lenio::Schema::Result::Org>

=cut

__PACKAGE__->belongs_to(
  "org",
  "Lenio::Schema::Result::Org",
  { id => "org_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 site_tasks

Type: has_many

Related object: L<Lenio::Schema::Result::SiteTask>

=cut

__PACKAGE__->has_many(
  "site_tasks",
  "Lenio::Schema::Result::SiteTask",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "tickets",
  "Lenio::Schema::Result::Ticket",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "site_groups",
  "Lenio::Schema::Result::SiteGroup",
  { "foreign.site_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-16 11:45:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:k2lbRiS+ORau+TuTEQwvcg

sub fys
{   my $self = shift;

    # Calculate financial years for this organisation
    my $fyfrom = $self->org->fyfrom->clone;
    my $now    = DateTime->now->add(years => 1); # Always add one to show next year's as well
    my @fys;
    while (DateTime->compare($now, $fyfrom) > 0)
    {
        my $y = $fyfrom->year;
        # Just show year in description if start is 1st jan
        my $name = ($fyfrom->month == 1 && $fyfrom->day == 1) ? $y : "$y-".($y+1);
        push @fys, { name => $name, year => $y };
        $fyfrom->add({ years => 1 });
    }

    \@fys;
}

sub fullname
{   my $self = shift;
    $self->name." (".$self->org->name.")";
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
