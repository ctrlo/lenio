=pod
Lenio - Web-based Facilities Management Software
Copyright (C) 2013 A Beverley

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

package Lenio::Ticket;

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use Ouch;

use Lenio::Schema;
use Lenio::FY;

sub view($)
{   my ($class, $id) = @_;
    my $ticket_rs = rset('Ticket');
    $ticket_rs->find($id);
}

sub attach_summary
{   my ($class, $ticket_id) = @_;
    my @attaches = rset('Attach')->search({
        ticket_id => $ticket_id,
    },{
        select => [qw/id name mimetype/],
    })->all;
    \@attaches;
}

sub all($)
{   my ($class, $login, $args) = @_;
    my $search = {};
    $search->{'site_task.site_id'} = $args->{site_id} if $args->{site_id};
    $search->{'site_task.task_id'} = undef if $args->{adhoc_only};
    $search->{'login_orgs.login_id'} = $login->{id} unless $login->{is_admin};
    $search->{'site_task.task_id'} = $args->{task_id} if defined $args->{task_id};
    if ($args->{uncompleted_only})
    {
        $search->{completed} = undef;
    }
    if (defined $args->{task_tickets})
    {
        $search->{task_id} = $args->{task_tickets}
            ? { '!=' => undef }
            : undef;
    }
    elsif ($args->{fy} && $args->{site_id})
    {
        # Work out date to take costs from (ie the financial year)
        my $dtf = schema->storage->datetime_parser;
        my $fy = Lenio::FY->new($args->{site_id}, $args->{fy});
        $search->{'-or'} = [
            {
                completed => {
                    -between => [
                        $dtf->format_datetime($fy->costfrom),
                        $dtf->format_datetime($fy->costto),
                    ],
                },
            },
            {
                completed => undef,
                planned   => {
                    -between => [
                        $dtf->format_datetime($fy->costfrom),
                        $dtf->format_datetime($fy->costto),
                    ],
                },
            },
        ];
    }

    rset('Ticket')->search($search, {
        prefetch => {
            'site_task' => {
                'site' => {
                    'org' => 'login_orgs'
                }
            }
        },
        order_by => 'me.id',
    });
}

sub new($$)
{   my ($class, $ticket) = @_;

    my $parser = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
         time_zone => 'local',
    );

    if ($ticket->{planned})
    {
        $ticket->{planned} = $parser->parse_datetime($ticket->{planned})
            or ouch 'badparam', "Please enter a valid planned date";
    }
    else {
        # Stop 0000-00-00 being inserted as a date for a blank value
        $ticket->{planned} = undef;
    }

    if ($ticket->{completed})
    {
        $ticket->{completed} = $parser->parse_datetime($ticket->{completed})
            or ouch 'badparam', "Please enter a completed date";
    }
    else {
        $ticket->{completed} = undef;
    }

    my $task_id = delete $ticket->{task_id} || undef; # Can be NULL when unrelated to a task
    my $login = delete $ticket->{login};
    my $site_id = delete $ticket->{site_id}
        or ouch 'nositeid', "No site ID specified";

    my $id = delete $ticket->{id}; # Update instead of create

    if (my $comment = delete $ticket->{comment})
    {
        $ticket->{comments} = [{ text => $comment, datetime => DateTime->now, login_id => $login->{id} }];
    }

    # site_id is in the relationship site_task, not main table. Only for create new
    $ticket->{site_task} = { task_id => $task_id, site_id => $site_id } unless $id;

    if ($id)
    {
        my $iss = rset('Ticket')->find($id)
            or ouch 'invalidid', "Unable to find specified ticket ID";
        $iss->update($ticket)
            or ouch 'dbfail', "Database error when updating ticket";
        $iss;
    }
    else {
        rset('Ticket')->create($ticket)
            or ouch 'dbfail', "Database error when creating ticket";
    }
}

sub commentAdd($$$)
{   my ($self, $ticket) = @_;
    my $comment_rs = rset('Comment');
    $comment_rs->create({
        ticket_id => $ticket->{id},
        text     => $ticket->{comment},
        login_id => $ticket->{login}->{id},
        datetime => DateTime->now,
    }) or ouch 'dbfail', "There was a database error when adding the comment";
}

sub attachAdd($)
{   my ($self, $file, $id) = @_;
    my $attach = {
        name        => $file->basename,
        ticket_id   => $id,
        content     => $file->content,
        mimetype    => $file->type,
    };
    my $attach_rs = rset('Attach');
    $attach_rs->create($attach)
        or ouch 'dbfail', "There was a database error when attaching the file";
}

sub attachRm($$)
{   my ($self, $id) = @_;
    my $attach_rs = rset('Attach')->find($id)
        or ouch 'badid', "The attachment ID could not be found";
    $attach_rs->delete
        or ouch 'dbfail', "There was a database error when deleting the attachment";
}

sub attachGet($)
{   my ($self, $attach) = @_;
    my $attach_rs = rset('Attach');
    $attach_rs->find($attach);
}

sub delete
{   my ($self, $id) = @_;
    my $ticket = rset('Ticket')->find($id)
        or ouch 'invalidid', "Unable to find specified ticket ID";
    rset('SiteTask')->search({ ticket_id => $id })->delete;
    rset('Comment')->search({ ticket_id => $id })->delete;
    rset('Attach')->search({ ticket_id => $id })->delete;
    $ticket->delete;
}

1;
