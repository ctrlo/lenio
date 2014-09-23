package Lenio::Schema::Result::SiteSingleTask;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

# For the time being this is necessary even for virtual views
__PACKAGE__->table("site_single_task");

#
# ->add_columns, etc.
#

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
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "site_check",
  { data_type => "tinyint", default_value => 1, is_nullable => 0 },
  "planned",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "completed",
  { data_type => "date", datetime_undef_if_invalid => 1, is_nullable => 1 },
  "cost_planned",
  { data_type => "decimal", is_nullable => 1, size => [10, 2] },
  "cost_actual",
  { data_type => "decimal", is_nullable => 1, size => [10, 2] },
  "site_task_id",
  { data_type => "integer", is_nullable => 1 },
  "is_extant",
  { data_type => "integer", is_nullable => 0 },
);

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(q[
SELECT me.id, me.name, me.description, me.period_unit, me.period_qty, me.global, me.site_check, MAX( ticket.completed ) AS completed, MAX( ticket.planned ) AS planned, SUM( ticket.cost_planned ) AS cost_planned, SUM( ticket.cost_actual ) AS cost_actual, site_task.id AS site_task_id, MIN(IFNULL(ticket_id, -1)) AS is_extant, site_task.site_id AS site_id
FROM task me
LEFT JOIN site_task ON ( site_task.site_id = ? AND site_task.task_id = me.id )
LEFT JOIN site site ON site.id = site_task.site_id
LEFT JOIN ticket ticket ON ticket.id = site_task.ticket_id
GROUP BY id
]);

