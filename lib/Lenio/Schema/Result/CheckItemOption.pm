use utf8;
package Lenio::Schema::Result::CheckItemOption;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("check_item_option");

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "check_item_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_deleted",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "check_item",
  "Lenio::Schema::Result::CheckItem",
  { id => "check_item_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "NO ACTION",
  },
);

1;
