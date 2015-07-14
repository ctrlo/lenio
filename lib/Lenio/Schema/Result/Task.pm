use utf8;
package Lenio::Schema::Result::Task;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Task

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

=head1 TABLE: C<task>

=cut

__PACKAGE__->table("task");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 1
  size: 45

=head2 description

  data_type: 'text'
  is_nullable: 1

=head2 period_unit

  data_type: 'varchar'
  is_nullable: 0
  size: 45

=head2 period_qty

  data_type: 'integer'
  is_nullable: 0

=head2 global

  data_type: 'smallint'
  default_value: 1
  is_nullable: 0

=head2 site_check

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "period_unit",
  { data_type => "varchar", is_nullable => 0, size => 45 },
  "period_qty",
  { data_type => "integer", is_nullable => 0 },
  "global",
  { data_type => "smallint", default_value => 1, is_nullable => 0 },
  "site_check",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
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

=head2 check_items

Type: has_many

Related object: L<Lenio::Schema::Result::CheckItem>

=cut

__PACKAGE__->has_many(
  "check_items",
  "Lenio::Schema::Result::CheckItem",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 site_tasks

Type: has_many

Related object: L<Lenio::Schema::Result::SiteTask>

=cut

__PACKAGE__->has_many(
  "site_tasks",
  "Lenio::Schema::Result::SiteTask",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2014-09-06 19:24:09
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WVfOtfrtfAKL9fmyassgWg

__PACKAGE__->load_components(qw(ParameterizedJoinHack));
__PACKAGE__->parameterized_has_many(
  site_single_tasks => 'Lenio::Schema::Result::SiteTask',
  [ [ qw(site_id) ], sub {
      my $args = shift;
      +{
        "$args->{foreign_alias}.task_id" =>
          { -ident => "$args->{self_alias}.id" },
        "$args->{foreign_alias}.site_id" =>
          $_{site_id}
      }
    }
  ]
);

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
