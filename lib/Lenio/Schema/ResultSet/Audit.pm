package Lenio::Schema::ResultSet::Audit;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use DateTime;

sub user_action
{   my ($self, %options) = @_;

    $self->create({
        login_id    => $options{login_id},
        description => $options{description},
        type        => 'user_action',
        method      => $options{method},
        url         => $options{url},
        datetime    => DateTime->now,
    });
}

sub login_change
{   my ($self, $login_id, $description) = @_;

    $self->create({
        login_id    => $login_id,
        description => $description,
        type        => 'login_change',
        datetime    => DateTime->now,
    });
}

sub login_success
{   my ($self, $username, $login_id) = @_;

    $self->create({
        login_id    => $login_id,
        description => "Successful login by username $username",
        type        => 'login_success',
        datetime    => DateTime->now,
    });
}

sub logout
{   my ($self, $username, $login_id) = @_;

    $self->schema->resultset('Audit')->create({
        login_id    => $login_id,
        description => "Logout by username $username",
        type        => 'logout',
        datetime    => DateTime->now,
    });
}

sub login_failure
{   my ($self, $username) = @_;

    $self->schema->resultset('Audit')->create({
        description => "Login failure using username $username",
        type        => 'login_failure',
        datetime    => DateTime->now,
    });
}

1;
