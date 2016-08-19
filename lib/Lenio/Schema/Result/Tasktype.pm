use utf8;
package Lenio::Schema::Result::Tasktype;

use Log::Report;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Tasktype

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

=head1 TABLE: C<tasktype>

=cut

__PACKAGE__->table("tasktype");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 tasks

Type: has_many

Related object: L<Lenio::Schema::Result::Task>

=cut

__PACKAGE__->has_many(
  "tasks",
  "Lenio::Schema::Result::Task",
  { "foreign.tasktype_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-16 11:45:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:aFHkgq2UX1ziP6orsc+X/A

sub validate {
    my $self = shift;
    error __"Please enter a name for the type of task" unless $self->name;
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
