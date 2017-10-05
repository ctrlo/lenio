package Lenio::Schema::ResultSet::Invoice;

use strict;
use warnings;
use base qw(DBIx::Class::ResultSet);

use Log::Report;

sub summary
{   my ($self, %args) = @_;
    my $search = {};

    $search->{'site.id'}   = $args{site_id} if $args{site_id};
    $search->{'login_orgs.login_id'} = $args{login}->id unless $args{login}->is_admin;
    $search->{'ticket.task_id'}   = $args{task_id} if defined $args{task_id};

    $args{sort} ||= '';
    my $order_by = $args{sort} eq 'title'
        ? 'ticket.name'
        : $args{sort} eq 'site'
        ? 'site.name'
        : $args{sort} eq 'date'
        ? 'me.datetime'
        : 'me.id';
    $order_by = { -desc => $order_by} if $args{sort_desc};
    $self->search($search, {
        prefetch => {
            ticket => {
                'site' => {
                    'org' => 'login_orgs'
                },
            },
        },
        order_by => $order_by,
    })->all;
}

1;
