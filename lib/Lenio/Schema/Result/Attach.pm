use utf8;
package Lenio::Schema::Result::Attach;

use Lenio::Config;
use Log::Report;
use Path::Class qw(dir file);

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Attach

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

=head1 TABLE: C<attach>

=cut

__PACKAGE__->table("attach");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0
  size: 1024

=head2 ticket_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 mimetype

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "ticket_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "mimetype",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 ticket

Type: belongs_to

Related object: L<Lenio::Schema::Result::Ticket>

=cut

__PACKAGE__->belongs_to(
  "ticket",
  "Lenio::Schema::Result::Ticket",
  { id => "ticket_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-08 13:50:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:+eHAr6ME56EmKKlzz+/UGg

sub content
{   my $self = shift;
    my $file = idtofile($self->id);
    -e $file or error "Unable to locate file";
    $file;
}

sub update_file
{   my ($self, $upload) = @_;
    error __"Invalid upload: content of file was blank"
        unless $upload->content;
    my $target = idtofile($self->id);
    $target->dir->mkpath;
    $upload->copy_to($target)
        or error __"Failed to insert file";
}

sub idtofile
{   # msgid 1234567 -> 001/234/567
    my $msgid = shift;
    my $config = Lenio::Config->instance;
    my $attdir = $config->lenio->{attachments}
        or panic "Attachments dir not configured";
    $msgid
        or panic "ID needs to be passed to idtodir";
    my $id = sprintf "%09d", $msgid;
    $id =~ s!(\d\d\d)!$1/!g;
    $id =~ s!/$!!;
    file($attdir, $id);
}

1;
