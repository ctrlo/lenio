use utf8;
package Lenio::Schema::Result::Audit;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("audit");

__PACKAGE__->add_columns(
  "id",
  { data_type => "int", is_auto_increment => 1, is_nullable => 0 },
  "login_id",
  { data_type => "int", is_foreign_key => 1, is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "method",
  { data_type => "varchar", is_nullable => 1, size => 45 },
  "url",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 1 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "login",
  "Lenio::Schema::Result::Login",
  { id => "login_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

1;
