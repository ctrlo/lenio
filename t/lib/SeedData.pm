package t::lib::SeedData;

use strict;
use warnings;

use Log::Report;
use Lenio::Schema;
use Lenio::Schema::Result::Task;

use Moo;
use MooX::Types::MooseLike::Base qw(:all);

has data => (
    is      => 'ro',
    builder => sub {
        +{
            tasks => [
                {
                    name        => 'Task 1',
                    description => 'Task 1 description',
                    period_qty  => 7,
                    period_unit => 'day',
                }, {
                    name        => 'Task 2',
                    description => 'Task 2 description',
                    period_qty  => 1,
                    period_unit => 'month',
                }, {
                    name        => 'Task 3',
                    description => 'Task 3 description',
                    period_qty  => 1,
                    period_unit => 'day',
                }
            ],
            checks => [
                {
                    name        => 'Check 1',
                    description => 'Check 1 description',
                    period_qty  => 7,
                    period_unit => 'day',
                    check_items => [qw/check_item1 check_item2/],
                },
                {
                    name        => 'Check 2',
                    description => 'Check 2 description',
                    period_qty  => 1,
                    period_unit => 'day',
                    check_items => [qw/check_item1/],
                },
                {
                    name        => 'Check 3',
                    description => 'Check 3 description',
                    period_qty  => 1,
                    period_unit => 'month',
                    check_items => [qw/check_item1/],
                },
            ],
            site => 'Site 1',
            org  => 'Org 1',
            contractors => [
                {
                    name => 'Contractor 1',
                },
            ],
        }
    },
);

has schema => (
    is => 'lazy',
);

sub _build_schema
{   my $self = shift;
    my $schema = Lenio::Schema->connect({
        dsn             => 'dbi:SQLite:dbname=:memory:',
        on_connect_call => 'use_foreign_keys',
        quote_names     => 1,
    });
    $schema->deploy;
    $schema;
}

has org => (
    is => 'lazy',
);

sub _build_org
{   my $self = shift;
    $self->schema->resultset('Org')->create({
        name   => $self->data->{org},
        fyfrom => '2015-04-01',
    });
}

has site => (
    is => 'lazy',
);

sub _build_site
{   my $self = shift;
    $self->schema->resultset('Site')->create({
        name   => $self->data->{site},
        org_id => $self->org->id,
    });
}

has login => (
    is => 'lazy',
);

sub _build_login
{   my $self = shift;
    my $org = $self->org;
    my $login = $self->schema->resultset('Login')->create({
        username => 'user@example.com',
        email    => 'user@example.com',
        password => 'XXX',
    });
    $self->schema->resultset('LoginOrg')->create({
        login_id => $login->id,
        org_id   => $org->id,
    });
    $login;
}

has tasktype => (
    is => 'lazy',
);

sub _build_tasktype
{   my $self = shift;
    $self->schema->resultset('Tasktype')->create({
        name => 'Tasktype 1',
    });
}

has tasks => (
    is  => 'lazy',
    isa => ArrayRef,
);

sub _build_tasks
{   my $self = shift;
    my @tasks;
    foreach my $t (@{$self->data->{tasks}})
    {
        my $task = $self->schema->resultset('Task')->new({
            global      => 1,
            name        => $t->{name},
            description => $t->{description},
            tasktype_id => $self->tasktype->id,
            period_qty  => $t->{period_qty},
            period_unit => $t->{period_unit},
        });
        $task->set_site_id($self->site->id);
        $task->insert;
        push @tasks, $task;
    }
    \@tasks;
}

# Selectively add checks
has select_checks => (
    is      => 'ro',
    isa     => ArrayRef,
    default => sub { [] },
);

has checks => (
    is  => 'lazy',
    isa => ArrayRef,
);

sub _build_checks
{   my $self = shift;
    $self->tasks; # Build tasks first to ensure consistent IDs as both share same table
    my @checks;
    my @source = @{$self->data->{checks}};
    my %select = map { $_ => 1 } @{$self->select_checks};
    @source = grep { $select{$_->{name}} } @source if %select;
    foreach my $c (@source)
    {
        my $check = $self->schema->resultset('Task')->new({
            global      => 1,
            name        => $c->{name},
            description => $c->{description},
            site_check  => 1,
            period_qty  => $c->{period_qty},
            period_unit => $c->{period_unit},
        });
        $check->set_site_id($self->site->id);
        $check->insert;
        foreach (@{$c->{check_items}})
        {
            $self->schema->resultset('CheckItem')->create({
                task_id => $check->id,
                name    => $_,
            });
        }
        push @checks, $check;
    }
    \@checks;
}

has contractors => (
    is  => 'lazy',
    isa => ArrayRef,
);

sub _build_contractors
{   my $self = shift;
    my @contractors;
    foreach my $contractor (@{$self->data->{contractors}})
    {
        push @contractors, $self->schema->resultset('Contractor')->create({
            name => $contractor->{name},
        });
    }
    \@contractors;
}

1;

