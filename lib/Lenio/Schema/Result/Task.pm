use utf8;
package Lenio::Schema::Result::Task;

use Log::Report;

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

__PACKAGE__->mk_group_accessors('simple' => qw/set_site_id/);
__PACKAGE__->mk_group_accessors('column' => qw/cost_planned cost_actual/);
__PACKAGE__->load_components("InflateColumn::DateTime", "+Lenio::DBIC");

=head1 TABLE: C<task>

=cut

__PACKAGE__->table("task");


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

=head2 tasktype_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 deleted

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
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
  "tasktype_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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

=head2 check_items

Type: has_many

Related object: L<Lenio::Schema::Result::CheckItem>

=cut

__PACKAGE__->has_many(
  "check_items",
  "Lenio::Schema::Result::CheckItem",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 1 },
);

=head2 site_tasks

Type: has_many

Related object: L<Lenio::Schema::Result::SiteTask>

=cut

our $SITEID;
__PACKAGE__->has_many(
  "site_tasks",
  "Lenio::Schema::Result::SiteTask",
  sub {
      my $args = shift;
      my $return = {
          "$args->{foreign_alias}.task_id"  => { -ident => "$args->{self_alias}.id" },
      };
      $return->{"$args->{foreign_alias}.site_id"} = $SITEID
          if $SITEID;
      return $return;
  },
  { cascade_copy => 0, cascade_delete => 1 },
);

__PACKAGE__->has_many(
  "tickets",
  "Lenio::Schema::Result::Ticket",
  { "foreign.task_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 1 },
);

=head2 tasktype

Type: belongs_to

Related object: L<Lenio::Schema::Result::Tasktype>

=cut

__PACKAGE__->belongs_to(
  "tasktype",
  "Lenio::Schema::Result::Tasktype",
  { id => "tasktype_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

__PACKAGE__->might_have(
  "site_task_local",
  "Lenio::Schema::Result::SiteTask",
  sub {
      my $args = shift;
      return {
        "$args->{foreign_alias}.task_id" =>
            { -ident => "$args->{self_alias}.id" },
        "$args->{self_alias}.global" =>
            { '=', "0" },
      };
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-16 11:45:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:mrxO7r3zukvdTmr3R5FuOg


sub strike {
    my $self = shift;
    return $self->get_column('site_has_task') ? 0 : 1;
}

sub validate {
    my $self = shift;

    my $name = $self->name;
    $name =~ s/^\h+//;
    $name =~ s/\h+$//;
    $name
        or error __"Please provide a name for the task";
    $self->name($name);
    $self->description
        or error __"Please provide a description for the task";
    $self->period_qty
        or error __"Please specify the period frequency";
    $self->period_unit
        or error __"Please specify the period units";
    if ($self->period_unit eq 'week')
    {
        $self->period_unit('day');
        $self->period_qty($self->period_qty * 7);
    }
}

sub after_create
{   my $self = shift;
    my $schema = $self->result_source->schema;
    if ($self->set_site_id)
    {
        $schema->resultset('SiteTask')->create({
            task_id => $self->id,
            site_id => $self->set_site_id,
        });
    }
}

sub last_completed
{   my $self = shift;
    my $schema = $self->result_source->schema;
    my $last_completed = $self->get_column('last_completed')
        or return undef;
    $self->parse_dt($last_completed);
}

sub last_planned
{   my $self = shift;
    my $schema = $self->result_source->schema;
    my $last_planned = $self->get_column('last_planned')
        or return undef;
    $self->parse_dt($last_planned);
}

sub next_planned
{   my $self = shift;
    my $schema = $self->result_source->schema;
    my $next_planned = $self->get_column('next_planned')
        or return undef;
    $self->parse_dt($next_planned);
}

sub contractor_name
{   my $self = shift;
    $self->get_column('contractor_name');
}

sub inflate_result {
    my $self = shift;
    my $data = $_[1];
    if ($data->{period_unit} eq 'day' && $data->{period_qty} % 7 == 0)
    {
        $data->{period_qty} = $data->{period_qty} / 7;
        $data->{period_unit} = 'week';
    }
    $self->next::method(@_);
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
