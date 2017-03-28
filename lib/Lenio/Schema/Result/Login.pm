use utf8;
package Lenio::Schema::Result::Login;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Lenio::Schema::Result::Login

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

use DateTime;

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<login>

=cut

__PACKAGE__->table("login");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 firstname

  data_type: 'text'
  is_nullable: 1

=head2 surname

  data_type: 'text'
  is_nullable: 1

=head2 password

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 is_admin

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 pwdreset

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 email_comment

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 email_ticket

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 only_mine

  data_type: 'smallint'
  default_value: 0
  is_nullable: 0

=head2 deleted

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "firstname",
  { data_type => "text", is_nullable => 1, size => 128 },
  "surname",
  { data_type => "text", is_nullable => 1, size => 128 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "is_admin",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "pwdreset",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "email_comment",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "email_ticket",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
  "only_mine",
  { data_type => "smallint", default_value => 0, is_nullable => 0 },
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

=head2 checks_done

Type: has_many

Related object: L<Lenio::Schema::Result::CheckDone>

=cut

__PACKAGE__->has_many(
  "checks_done",
  "Lenio::Schema::Result::CheckDone",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 comments

Type: has_many

Related object: L<Lenio::Schema::Result::Comment>

=cut

__PACKAGE__->has_many(
  "comments",
  "Lenio::Schema::Result::Comment",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_notices

Type: has_many

Related object: L<Lenio::Schema::Result::LoginNotice>

=cut

__PACKAGE__->has_many(
  "login_notices",
  "Lenio::Schema::Result::LoginNotice",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_orgs

Type: has_many

Related object: L<Lenio::Schema::Result::LoginOrg>

=cut

__PACKAGE__->has_many(
  "login_orgs",
  "Lenio::Schema::Result::LoginOrg",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 login_permissions

Type: has_many

Related object: L<Lenio::Schema::Result::LoginPermission>

=cut

__PACKAGE__->has_many(
  "login_permissions",
  "Lenio::Schema::Result::LoginPermission",
  { "foreign.login_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-09-16 11:45:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cv++JIacEgBu3PcKeqElCw

sub update_orgs
{   my ($self, @org_new) = @_;
    my $schema = $self->result_source->schema;
    my $guard = $schema->txn_scope_guard;
    my @org_old = $schema->resultset('LoginOrg')->search({ login_id => $self->id })->all;
    # Delete organisation memberships that are no longer needed
    foreach my $org_old (@org_old)
    {
        $schema->resultset('LoginOrg')->search({ login_id => $self->id, org_id => $org_old->org_id })->delete
            unless grep { $org_old->org_id == $_ } @org_new;
    }
    # Add organisation memberships that are not already there
    foreach my $org_new (@org_new)
    {
        $schema->resultset('LoginOrg')->create({ login_id => $self->id, org_id => $org_new })
            unless grep { $org_new == $_->org_id } @org_old;
    }
    $guard->commit;
}

sub has_site
{   my ($self, @site_ids) = @_;
    return 1 if $self->is_admin;
    $self->result_source->resultset->search({
        'me.id'    => $self->id,
        'sites.id' => [@site_ids],
    },{
        join => {
            login_orgs => {
                org => 'sites',
            },
        },
    })->count;
}

sub has_site_task
{   my ($self, $site_task_id) = @_;
    return 1 if $self->is_admin;
    $self->result_source->resultset->search({
        'me.id'         => $self->id,
        'site_tasks.id' => $site_task_id,
    },{
        join => {
            login_orgs => {
                org => {
                    'sites' => 'site_tasks',
                },
            },
        },
    })->count;
}

sub sites
{   my $self = shift;
    my @sites;
    if ($self->is_admin)
    {
        my $site_rs = $self->result_source->schema->resultset('Site')->search({}, { prefetch => 'org' });
        @sites = $site_rs->all;
    }
    else {
        my @login_orgs = $self->login_orgs->all;
        foreach my $login_org (@login_orgs) {
            push @sites, $login_org->org->sites->all;
        }
    }
    @sites;
}

sub full_name
{   my $self = shift;
    ($self->surname||'') . ", " . ($self->firstname||'');
}

sub disable
{   my $self = shift;
    $self->update({ deleted => DateTime->now });
}

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
