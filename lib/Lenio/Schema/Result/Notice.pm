use utf8;
package Lenio::Schema::Result::Notice;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Notice

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

=head1 TABLE: C<notice>

=cut

__PACKAGE__->table("notice");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 text

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "text",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 login_notices

Type: has_many

Related object: L<Lenio::Schema::Result::LoginNotice>

=cut

__PACKAGE__->has_many(
  "login_notices",
  "Lenio::Schema::Result::LoginNotice",
  { "foreign.notice_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07025 @ 2014-02-20 00:04:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:BcynCYMICYNALTsgmZP8jg

sub validate {
    my $self = shift;
    error __"Please enter some text for the noticer" unless $self->text;
}

sub after_create
{   my $self = shift;
    my $schema = $self->result_source->schema;
    my @toshow;
    foreach my $login ($schema->resultset('Login')->search)
    {
        push @toshow, { notice_id => $self->id, login_id => $login->id };
    }
    $schema->resultset('LoginNotice')->populate(\@toshow);
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
