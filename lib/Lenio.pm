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

package Lenio;
use Crypt::YAPassGen;
use Dancer2;
use Dancer2::Core::Cookie;
use JSON qw(encode_json);
use Lenio::Task;
use Lenio::Ticket;
use Lenio::Site;
use Lenio::Org;
use Lenio::Login;
use Lenio::Notice;
use Lenio::Contractor;
use Lenio::Email;
use Ouch;
use Text::CSV;

use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;

set behind_proxy => config->{behind_proxy};

our $VERSION = '0.1';

hook before => sub {

    # Static content
    return if request->uri =~ m!^/(error|js|css|login|logout|favicon|tmpls|fonts|images)!;
    # Used to display error messages
    return if param 'error';

    my $user = logged_in_user
        or return;

    my $login_rs = Lenio::Login->login({ id => $user->{id} });

    # Sites associated with the user 
    forward '/error', { 'error' => 'There are no sites associated with this username' }
        unless (my @sites = Lenio::Site->all($user->{id}));

    my @notices = $login_rs->login_notices;
 
    my $login = {
        id        => $user->{id},
        username  => $login_rs->username,
        sites     => \@sites,
        is_admin  => $login_rs->is_admin,
        notices   => \@notices,
        surname   => $login_rs->surname,
        firstname => $login_rs->firstname,
    };

    # Select individual site and check user has access
    if ( param('site') && param('site') eq 'all' ) {
        session site_id => '';
    }
    elsif ( param('site') ) {
        session site_id => param('site')
            if Lenio::Login->hasSite($login, param('site'));
    }
    session(site_id => $sites[0]->id) unless (defined session('site_id'));
    $login->{site}     = Lenio::Site->site(session('site_id'));
    $login->{site_fys} = Lenio::Site->fys(session('site_id'));
    my $fy = session 'fy';
    $fy = param('fy') if param('fy');
    $fy = $login->{site_fys}[-1]->{year}
        unless grep { $fy == $_->{year} } @{$login->{site_fys}};
    $login->{fy} = $fy;
    session 'fy' => $fy;

    var login => $login;
};

get '/' => require_login sub {
    my $local = var('login')->{is_admin} ? 0 : 1; # Only show local tasks for non-admin
    my $sites = var('login')->{is_admin}
              ? session('site_id')
              : session('site_id') ? session('site_id') : var('login')->{sites};
    my @overdue = Lenio::Task->overdue( $sites, {local => $local} );
    my $output  = template 'index' => {
        messages   => session('messages'),
        dateformat => config->{lenio}->{dateformat},
        tasks      => \@overdue,
        login      => var('login'),
        page       => 'index'
    };
    session 'messages' => [];
    $output;
};

sub login_page_handler
{
    my $messages = session('messages') || undef;
    messageAdd({ success => "A password reset request has been sent if the email address
           entered was valid" }) if defined param('reset_sent');
    messageAdd({ danger => "Username or password not valid" })
        if defined param('login_failed');
    my $output = template login => {
        page                => 'login',
        messages            => $messages,
        new_password        => param('new_password'),
        password_code_valid => param('password_code_valid'),
        reset_code          => param('new_password') || param('password_code_valid'),
    };
    session 'messages' => [];
    $output;
}

# Dismiss a notice
get '/close/:id' => require_login sub {
    Lenio::Notice->dismiss(var('login'), param('id'));
};

get '/error' => require_login sub {
    my $output  = template 'error' => {
        error => param('error'),
        page  => 'error',
    };
    session 'messages' => [];
    $output;
};

any qr{^/user/?([\w]*)/?([\d]*)$} => require_login sub {
    my ( $action, $id ) = splat;

    my $is_admin = var('login')->{is_admin};

    my $username;
    # Stop normal users performing admin tasks on other users
    if ($is_admin)
    {
        $username = param('username');
    }
    else {
        $username = logged_in_user->{username};
        $action = 'view';
    }

    Lenio::Login->delete(param('delete'))
        if $is_admin && param('delete');

    my @logins;
    if ( $action eq 'new' || $action eq 'view' ) {

        if ( param('submit') ) {
            my $adm = $is_admin && param('is_admin') ? 1 : 0;
            # param org_ids can be a scalar, array or undefined, depending how many where submitted
            my %login = (
                username      => param('email'),
                email         => param('email'),
                firstname     => param('firstname'),
                surname       => param('surname'),
                is_admin      => $adm,
            );
            if ($is_admin && $action eq 'new')
            {
                # Default to on
                $login{email_comment} = 1;
                $login{email_ticket} = 1;
            }
            elsif (!$is_admin)
            {
                # Option not presented to admins
                $login{email_comment} = param('email_comment') ? 1 : 0;
                $login{email_ticket}  = param('email_ticket') ? 1 : 0;
            }

            if ($username)
            {
                update_user $username, realm => 'dbic', %login;
            }
            else {
                if (Lenio::Login->exists($login{username}))
                {
                    eval { ouch 'exists', "The email address already exists" };
                }
                else {
                    my $newuser = create_user %login, realm => 'dbic', email_welcome => 1;
                    $username = $login{username};
                }
            }
            if (hug)
            {
                messageAdd({ danger => bleep });
                if ($@->isa('Ouch') && $@->data)
                {
                    foreach my $error (@{$@->data})
                    {
                        messageAdd({ danger => $error });
                    }
                }
            }
            else {
                if ($is_admin)
                {
                    my $org_ids = !defined param('org_ids')
                                ? []
                                : ref param('org_ids') eq 'ARRAY'
                                ? param('org_ids')
                                : [ param('org_ids') ];
                    Lenio::Login->update_orgs($username, $org_ids);
                }
                my $a = $action eq 'new' ? 'added' : 'updated';
                my $forward = $is_admin ? 'user' : '';
                forwardHome({ success => "User has been successfully $a" }, $forward);
            }
        }
        if ($action eq 'view')
        {
            my $login = Lenio::Login->view($id)
              or forwardHome({ danger => 'Requested user not found' });
            push @logins, $login;
        }
    }
    else {
        $action = '';
        @logins = Lenio::Login->all;
    }

    my @orgs = Lenio::Org->all;
    my $output = template 'user' => {
        action    => $action,
        id        => $id,
        logins    => \@logins,
        orgs      => \@orgs,
        messages  => session('messages'),
        login     => var('login'),
        page      => 'user'
    };
    session 'messages' => [];
    $output;
};

any qr{^/contractor/?([\w]*)/?([\d]*)$} => require_login sub {
    my ( $action, $id ) = splat;

    var('login')->{is_admin}
        or forwardHome({ danger => 'You do not have permission to view contractors' });

    if (param('delete'))
    {
        eval { Lenio::Contractor->delete(param('delete')) };
        if (hug)
        {
            messageAdd({ danger => bleep });
        }
        else {
            forwardHome({ success => 'Contractor has been successfully deleted' }, 'contractor');
        }
    }

    my @contractors;
    if (  $action eq 'new' )
    {
        if ( param('submit') )
        {
            my $contractor = {name => param('name')};
            eval { Lenio::Contractor->new($contractor) };
            if (hug)
            {
                messageAdd({ danger => bleep });
            }
            else {
                forwardHome({ success => 'Contractor has been successfully added' }, 'contractor');
            }
        }
    }
    elsif ( $action eq 'view' )
    {
        if ( param('submit') )
        {
            my $contractor = {
                name => param('name'),
                id   => $id,
            };
            eval { Lenio::Contractor->update($contractor) };
            if (hug)
            {
                messageAdd({ danger => bleep });
            }
            else {
                forwardHome({ success => 'Contractor has been successfully updated' }, 'contractor');
            }
        }
        my $contractor = Lenio::Contractor->view($id)
            or forwardHome({ danger => 'Requested contractor not found' });
        push @contractors, $contractor;
    }
    else {
        $action = '';
        @contractors = Lenio::Contractor->all;
    }

    my $output = template 'contractor' => {
        action      => $action,
        id          => $id,
        contractors => \@contractors,
        messages    => session('messages'),
        login       => var('login'),
        page        => 'contractor'
    };
    session 'messages' => [];
    $output;
};

any qr{^/notice/?([\w]*)/?([\d]*)$} => require_login sub {
    my ( $action, $id ) = splat;

    var('login')->{is_admin}
        or forwardHome({ danger => 'You do not have permission to view notice settings' });

    if (param('delete'))
    {
        eval { Lenio::Notice->delete(param('delete')) };
        if (hug)
        {
            messageAdd( { danger => bleep } );
        }
        else {
            forwardHome( { success => "The notice has been deleted" } );
        }
    }

    my @notices;
    if ($action eq 'new')
    {
        if (param('submit'))
        {
            my $notice = { text => param('text') };
            eval { Lenio::Notice->new($notice) };
            if (hug)
            {
                messageAdd( { danger => bleep } );
            }
            else {
                forwardHome(
                    { success => 'Notice has been successfully created' }, 'notice');
            }
        }
    }
    elsif ( $action eq 'view' )
    {
        if ( param('submit') )
        {
            my $notice = {
                text        => param('text'),
                id          => $id,
            };
            eval { Lenio::Notice->update($notice) };
            if (hug)
            {
                messageAdd( { danger => bleep } );
            }
            else {
                forwardHome(
                    { success => 'Notice has been successfully updated' }, 'notice');
            }
        }
        my $notice = Lenio::Notice->view($id)
            or forwardHome({ danger => 'Requested notice not found' });
        push @notices, $notice;
    }
    else {
        $action = '';
        @notices = Lenio::Notice->all;
    }

    my $output = template 'notice' => {
        action   => $action,
        id       => $id,
        notices  => \@notices,
        messages => session('messages'),
        login    => var('login'),
        page     => 'notice'
    };
    session 'messages' => [];
    $output;
};
 
any '/check/?:task_id?/?:check_done_id?/?' => require_login sub {

    my $task_id       = param 'task_id';
    my $check_done_id = param 'check_done_id';

    my $site_id = session 'site_id';
    $site_id or forwardHome({ danger => 'Please select a site before viewing site checks' });

    if (param 'submit_check_done')
    {
        # Log the completion of a site check
        # Check user has permission first
        forwardHome(
            { danger => "You do not have permission for site ID $site_id" } )
                unless Lenio::Login->hasSiteTask(var('login'), param('site_task_id') );

        my $params = params;
        
        eval { Lenio::Task->check_done(var('login'), $params) };
        if (hug)
        {
            messageAdd({ danger => bleep });
        }
        else {
            messageAdd({ success => 'Site checks have been recorded successfully' }, 'check');
        }
    }

    my $check = Lenio::Task->check($site_id, $task_id, $check_done_id) if $task_id;

    my @site_checks = Lenio::Task->site_checks($site_id);
    my $output = template 'check' => {
        check       => $check,
        site_checks => \@site_checks,
        dateformat  => config->{lenio}->{dateformat},
        messages    => session('messages'),
        login       => var('login'),
        page        => 'check',
    };
    session 'messages' => [];
    $output;
};

any qr{^/ticket/?([\w]*)/?([\d]*)/?([\d]*)/?([-\d]*)$} => require_login sub {
    my ( $action, $id, $site_id, $date ) = splat;

    my @tickets; my $task; my $attaches;
    if ($action eq 'new' || $action eq 'view')
    {
        my $ticket;
        if ($action eq 'view')
        {
            # Check whether the user has access to this ticket
            $ticket = Lenio::Ticket->view($id)
                or forwardHome({ danger => 'Requested ticket not found' });
            forwardHome(
                { danger => "You do not have permission for ticket ID $id" } )
                    unless Lenio::Login->hasSite(var('login'), $ticket->site_task->site_id);

            # Get attachment summary (so as not to retrieve file content)
            $attaches = Lenio::Ticket->attach_summary($id);

            if ( param('addcomment') ) {
                my $iss = {
                    id      => $id,
                    comment => param('comment'),
                    login   => var('login'),
                };
                eval { Lenio::Ticket->commentAdd($iss) };
                if (hug)
                {
                    messageAdd( { danger => bleep });
                }
                else {
                    my $args = { login       => var('login'),
                                 site_id     => $ticket->site_task->site_id,
                                 template    => 'ticket/comment',
                                 url         => "/ticket/view/".$id,
                                 name        => $ticket->name,
                                 subject     => "Ticket updated - ",
                                 description => $ticket->description,
                                 comment     => param('comment'),
                               };
                    Lenio::Email->send($args);
                }
            }
            if ( param('attach') ) {
                forwardHome(
                    { danger => 'You do not have permission to add attachments' } )
                        unless var('login')->{is_admin};

                my $file = request->upload('newattach');
                if ($file)
                {
                    eval { Lenio::Ticket->attachAdd($file, $id) };
                    if (hug)
                    {
                        messageAdd({ danger => bleep });
                    }
                    else {
                        messageAdd({ success => 'File has been added successfully' });
                    }
                }
                else {
                    messageAdd({ danger => 'Failed to receive uploaded file' });
                }
            }
            if ( param('attachrm') ) {
                forwardHome(
                    { danger => 'You do not have permission to delete attachments' } )
                        unless var('login')->{is_admin};

                eval { Lenio::Ticket->attachRm(param 'attachrm') };
                if (hug)
                {
                    messageAdd({ danger => bleep });
                }
                else {
                    messageAdd({ success => 'Attachment has been deleted successfully' });
                }
            }
            if (param 'delete')
            {
                forwardHome(
                    { danger => 'You do not have permission to delete this ticket' }
                ) unless var('login')->{is_admin} || $ticket->site_task->task->global == 0;
                Lenio::Ticket->delete($id);
                forwardHome(
                    { success => "Ticket has been successfully deleted" }, 'ticket');
            }

            push @tickets, $ticket;
        }

        if ( param('submit') ) {

            my $global;
            if ($action eq 'new')
            {
                # Find out if this is related to locally created task.
                # If so, allow dates to be input
                my $task = Lenio::Task->view($id);
                $global  = $task && $task->global ? 1 : 0;
            }

            my $completed = var('login')->{is_admin} || !$global ? param('completed') : undef;
            my $planned   = var('login')->{is_admin} || !$global ? param('planned') : undef;
            my $iss = {
                name           => param('name'),
                description    => param('description'),
                site_id        => param('site_id'),
                contractor_id  => param('contractor'),
                cost_planned   => param('cost_planned'),
                cost_actual    => param('cost_actual'),
                local_only     => param('local_only'),
                completed      => $completed,
                planned        => $planned,
            };

            # A normal user cannot edit a ticket that has already been created,
            # unless it is related to a locally created task
            if ($action eq 'view')
            {
                forwardHome(
                    { danger => 'You do not have permission to edit this ticket' }
                ) unless var('login')->{is_admin} || $ticket->local_only || $ticket->site_task->task->global == 0;
                $iss->{id} = $id;
            }
            else {
                $iss->{task_id} = $id;
                $iss->{comment} = param('comment');
                $iss->{login}   = var('login');
            }

            my $t; # Returned ticket
            eval { $t = Lenio::Ticket->new($iss) };
            if (hug)
            {
                messageAdd({ danger => bleep });
            }
            else {
                my $template; my $subject; my $status;
                if ($action eq 'view')
                {
                    $template = 'ticket/update';
                    $subject = "Ticket updated - ";
                    $status = 'updated';
                }
                else {
                    $template = 'ticket/new';
                    $subject = "New ticket - ";
                    $status = 'created';
                }
                my $args = { login       => var('login'),
                             site_id     => param('site_id'),
                             template    => $template,
                             url         => "/ticket/$action/".$t->id,
                             name        => $t->name,
                             subject     => $subject,
                             description => $t->description,
                             planned     => param('planned'),
                             completed   => param('completed'),
                           };
                # Assume send update to admin
                my $send_email = 1;
                # Do not send email update if new ticket and local, or is local_only and not changed
                $send_email = 0 if ((!$ticket && $t->local_only) || ($ticket && $ticket->local_only == 1 && $t->local_only == 1));
                # Send email update if not local site task
                $send_email = 0 if ($t->site_task->task && $t->site_task->task->global == 0);
                Lenio::Email->send($args) if $send_email;
                forwardHome(
                    { success => "Ticket has been successfully $status" }, 'ticket');
            }
        }
        if ($action eq 'new' && $id)
        {
            # Prefill ticket fields with initial values based on task
            my $task = Lenio::Task->view($id);
            my $sid  = ($task->site_tasks->all)[0]->site_id; # site_id associated with task
            # See if the user has permission to view associated task
            if ( var('login')->{is_admin}
                || (!$task->global && Lenio::Login->hasSite(var('login'), $sid))
            ) {
                my $ticket = {
                    name        => $task->name,
                    description => $task->description,
                    planned     => $date,
                    site_task   => {site_id => $site_id, task => { global => $task->global } }, # to match database schema
                    # global      => $task->global,
                };
                push @tickets, $ticket;
            }
        }
    }
    else {
        $action = '';
        my $uncompleted_only;
        my $task_id;
        if (param('task'))
        {
            $uncompleted_only = 0;
            $task_id          = param('task');
        }
        else {
            $uncompleted_only = 1;
        }
        @tickets = Lenio::Ticket->all(var('login'), {
            site_id          => session ('site_id'),
            uncompleted_only => $uncompleted_only,
            task_id          => $task_id,
        });
        $task = Lenio::Task->view($task_id) if $task_id;
    }

    my @contractors = Lenio::Contractor->all;
    my $output = template 'ticket' => {
        action      => $action,
        dateformat  => config->{lenio}->{dateformat},
        id          => $id,
        task        => $task,
        tickets     => \@tickets,
        attaches    => $attaches,
        contractors => \@contractors,
        messages    => session('messages'),
        login       => var('login'),
        page        => 'ticket'
    };
    session 'messages' => [];
    $output;
};

get '/attach/:file' => require_login sub {
    my $file = Lenio::Ticket->attachGet(param 'file');
    $file or 
        forwardHome({ danger => 'File not found' });
    my $data = $file->content;
    my $site_id = $file->ticket->site_task->site_id;
    if ( Lenio::Login->hasSite(var('login'), $site_id ))
    {
        send_file( \$data, content_type => $file->mimetype );
    } else {
        forwardHome(
            { danger => 'You do not have permission to view this file' } );
    }
};

any qr{^/task/?([\w]*)/?([\d]*)$} => require_login sub {
    my ( $action, $id ) = splat;

    if (var('login')->{is_admin})
    {
        if (param 'taskadd')
        {
            eval { Lenio::Site->taskAdd(session('site_id'), param('taskadd')) };
        }
        if (param 'taskrm')
        {
            eval { Lenio::Site->taskRm(session('site_id'), param('taskrm')) };
        }
        if (param 'taskdel')
        {
            eval { Lenio::Task->delete(param('taskdel')) };
        }
    }
    # Anyone can delete local tasks
    if (param 'localtaskdel')
    {
        eval { Lenio::Task->delete(param('localtaskdel')) }
            if Lenio::Login->hasSite(var('login'), Lenio::Task->site(param('localtaskdel')));
    }

    # Catch any errors from above operations
    messageAdd( { danger => bleep } )
        if hug;

    my @tasks; my @tasks_local; my @adhocs; my @site_checks;
    if (  $action eq 'new' ) {
        if ( param('submit') ) {
            my $task = {
                name        => param('name'),
                description => param('description'),
                period_qty  => param('period_qty'),
                period_unit => param('period_unit'),
            };
            if (var('login')->{is_admin})
            {
                $task->{global} = 1;
            }
            else
            {
                $task->{site_tasks} = [{ site_id => param('site_id') }];
                $task->{global}    = 0;
            }
            eval { Lenio::Task->new($task) };
            if (hug)
            {
                messageAdd( { danger => bleep } );
            }
            else {
                forwardHome(
                    { success => 'Service item has been successfully created' }, 'task' );
            }
        }
        @tasks = ({ site_id => session('site_id') });
    }
    elsif ( $action eq 'view' ) {

        # Check whether the user has access to this ticket
        my $task = Lenio::Task->view($id)
            or forwardHome({ danger => 'Requested service item not found' });
        my @sites = map { $_->site_id } $task->site_tasks->all;
        forwardHome(
            { danger => "You do not have permission for service item $id" } )
                unless $task->global || Lenio::Login->hasSite(var('login'), @sites);

        if ( param('submit') ) {
            forwardHome(
                { danger => 'You do not have permission to edit this item' } )
                    unless var('login')->{is_admin};

            my $ntask = {
                id          => $id,
                name        => param('name'),
                description => param('description'),
                period_qty  => param('period_qty'),
                period_unit => param('period_unit'),
            };
            eval { Lenio::Task->update($ntask) };
            if (hug)
            {
                messageAdd( { danger => bleep } );
            }
            else {
                forwardHome(
                    { success => 'Service item has been successfully updated' }, 'task' );
            }
            # Reload updated task from database (to prove update)
            my $task = Lenio::Task->view($id)
              or forwardHome({ danger => 'Requested service item not found' });
        }
        @tasks = ($task);
    }
    elsif ($action eq "check")
    {
        if (param 'submitcheck')
        {
            my $params = params;
            eval { Lenio::Task->check_update($id, $params) };
            if (hug)
            {
                messageAdd( { danger => bleep } );
            }
            elsif(param 'checkitem') {
                forwardHome(
                    { success => 'The check item has been added successfully' }, "task/check/$id" );
            }
            else {
                forwardHome(
                    { success => 'The site check has been successfully updated' }, 'task' );
            }
        }
        my $output = template 'check_edit' => {
            check       => Lenio::Task->check($id),
            login       => var('login'),
            site_id     => session('site_id'),
            messages    => session('messages'),
            login       => var('login'),
            page        => 'check'
        };
        session 'messages' => [];
        return $output;
    }
    else
    {
        my $csv = param('csv') || ""; # prevent warnings
        # Get all the global tasks.
        @tasks = Lenio::Task->summary(session ('site_id') || undef, {global => 1, fy => session('fy')});
        if ($csv eq 'service')
        {
            my $csv = Text::CSV->new;
            my @headings = qw/task applicable frequency_qty frequency_unit planned last_done cost_planned cost_actual/;
            $csv->combine(@headings);
            my $csvout = $csv->string."\n";
            foreach my $task (@tasks)
            {
                my @row = (
                    $task->{name},
                    $task->{strike} ? 'No' : 'Yes',
                    $task->{period_qty},
                    $task->{period_unit},
                    $task->{planned} && $task->{planned}->ymd,
                    $task->{completed} && $task->{completed}->ymd,
                    $task->{cost_planned},
                    $task->{cost_actual}
                );
                $csv->combine(@row);
                $csvout .= $csv->string."\n";
            }
            my $now = DateTime->now->ymd;
            my $site = var('login')->{site}->org->name;
            return send_file(
                \$csvout,
                content_type => 'text/csv',
                filename     => "$site service items $now.csv"
            );
        }

        # Get any adhoc tasks
        @adhocs = Lenio::Ticket->all(var('login'), { site_id => session ('site_id'), adhoc_only => 1, fy => session('fy') });
        if ($csv eq 'reactive')
        {
            my $csv = Text::CSV->new;
            my @headings = qw/title cost_planned cost_actual/;
            $csv->combine(@headings);
            my $csvout = $csv->string."\n";
            foreach my $adhoc (@adhocs)
            {
                my @row = (
                    $adhoc->name,
                    $adhoc->cost_planned,
                    $adhoc->cost_actual,
                );
                $csv->combine(@row);
                $csvout .= $csv->string."\n";
            }
            my $now = DateTime->now->ymd;
            my $site = var('login')->{site}->org->name;
            return send_file(
                \$csvout,
                content_type => 'text/csv',
                filename     => "$site reactive $now.csv"
            );
        }
        # Get all the local tasks
        @tasks_local = Lenio::Task->summary(session ('site_id') || undef, {global => 0, onlysite => 1, fy => session('fy')});
        # Get all the site checks
        @site_checks = Lenio::Task->site_checks(session ('site_id') || undef);
        $action = '';
    }

    my $output = template 'task' => {
        login       => var('login'),
        dateformat  => config->{lenio}->{dateformat},
        action      => $action,
        site_id     => session('site_id'),
        site_checks => \@site_checks,
        tasks       => \@tasks,
        tasks_local => \@tasks_local,
        adhocs      => \@adhocs,
        messages    => session('messages'),
        login       => var('login'),
        page        => 'task'
    };
    session 'messages' => [];
    $output;
};

get '/data' => require_login sub {

    # Epochs received from the calendar module are based on the timezone of the local
    # browser. So in BST, 24th August is requested as 23rd August 23:00. Rather than
    # trying to convert timezones, we keep things simple and round down any "from"
    # times and round up any "to" times.
    my $utc_offset = param('utc_offset') * -1;
    my $from  = DateTime->from_epoch( epoch => ( param('from') / 1000 ) )->add( minutes => $utc_offset );
    my $to    = DateTime->from_epoch( epoch => ( param('to') / 1000 ) )->add(minutes => $utc_offset );

    my @tasks;
    my @sites = session('site_id')
              ? ( Lenio::Site->site( session 'site_id' ) )
              : @{var('login')->{sites}};
    foreach my $site (@sites) {
        push @tasks, Lenio::Task->calendar_check( $from, $to, $site->id, var('login') );
        foreach my $task ( Lenio::Task->calendar( $from, $to, $site->id, var('login') ) ) {
            my $t = Lenio::Task->calPopulate($task, $site);
            push @tasks, $t if $t;
        }
    }
    _send_json ({
        success => 1,
        result => \@tasks
    });
};

sub forwardHome {
    if (my $message = shift)
    {
        my $text = ( values %$message )[0];
        my $type = ( keys %$message )[0];

        messageAdd($message);
    }
    my $page = shift || '';
    redirect "/$page";
}

sub messageAdd($) {
    my $message = shift;
    my $text    = ( values %$message )[0];
    my $type    = ( keys %$message )[0];
    my $msgs    = session 'messages';
    push @$msgs, { text => $text, type => $type };
    session 'messages' => $msgs;
}

sub _send_json
{   header "Cache-Control" => "max-age=0, must-revalidate, private";
    content_type 'application/json';
    encode_json(shift);
}

sub password_generator
{
    my $passgen  = Crypt::YAPassGen->new(algorithm  =>  'linear', length => 8);
    $passgen->generate();
}

true;
