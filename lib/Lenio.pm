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
use Dancer2;
use Dancer2::Core::Cookie;
use Lenio::Task;
use Lenio::Ticket;
use Lenio::Site;
use Lenio::Org;
use Lenio::Login;
use Lenio::Notice;
use Lenio::Contractor;
use Lenio::Email;
use Ouch;

set serializer => 'JSON';
our $VERSION = '0.1';

hook before => sub {

    # Static content
    return if request->uri =~ m!^/(error|js|css|login|favicon|tmpls|fonts|images)!;
    # Used to display error messages
    return if param 'error';

    redirect '/login' unless session('login_id');
    my $login_rs = Lenio::Login->login({ id => session('login_id') });

    # Sites associated with the user 
    forward '/error', { 'error' => 'There are no sites associated with this username' }
        unless (my @sites = Lenio::Site->all(session 'login_id'));

    my @notices = $login_rs->login_notices;
 
    my $login = {
        id        => session('login_id'),
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
    session(site_id => @sites[0]->id) unless (defined session('site_id'));
    $login->{site}     = Lenio::Site->site(session('site_id'));
    $login->{site_fys} = Lenio::Site->fys(session('site_id'));
    my $fy = session 'fy';
    $fy = param('fy') if param('fy');
    $fy = $login->{site_fys}[0]->{year}
        unless grep { $fy == $_->{year} } @{$login->{site_fys}};
    $login->{fy} = $fy;
    session 'fy' => $fy;

    var login => $login;
    # Assume we've displayed any messages. Reset array.
    session 'messages' => [];
};

get '/' => sub {
    my $local = var('login')->{is_admin} ? 0 : 1; # Only show local tasks for non-admin
    my $sites = var('login')->{is_admin}
              ? session('site_id')
              : session('site_id') ? session('site_id') : var('login')->{sites};
    my @overdue = Lenio::Task->overdue( $sites, {local => $local} );
    my $output  = template 'index' => {
        messages => session('messages'),
        tasks    => \@overdue,
        login    => var('login'),
        page     => 'index'
    };
    session 'messages' => [];
    $output;
};

any '/login' => sub {

    if (defined param('logout'))
    {
        context->destroy_session;
        forwardHome();
    }

    # Request a password reset
    if (param('resetpwd'))
    {
        Lenio::Login->resetRequest(param 'emailreset')
        ? messageAdd( { success => 'An email has been sent to your email address
            with a link to reset your password' } )
        : messageAdd( { danger => 'Failed to send a password reset link.
            Did you enter a valid email address?' } );
    }

    # Process a password reset
    my $reset;
    if (param('reset'))
    {
        my $args = {
            code      => param('reset'),
            password  => param('password'),
            password2 => param('password2'),
        };

        eval { $reset = Lenio::Login->resetProcess($args) };
        if (hug)
        {
            $reset = 1 if kiss('nomatch'); # Only show reset page for no match
            messageAdd({ danger => bleep });
        }
        elsif (!$reset) {
            forwardHome({ success => "Password was reset successfully" });
        }
    }

    # Attempt to login a user
    if (param('email'))
    {
        my $login;
        eval {
            $login = Lenio::Login->login({
                username => param('email'),
                password => param('password'),
            });
        };
        messageAdd({ danger => bleep }) if (hug);

        if ($login)
        {
            # Remember username?
            param('remember')
                ? cookie username => param('email'), expires => "60 days"
                : cookie username => '', expires => "-1 hour";
            session 'login_id' => $login->id;
            forwardHome();
        }
    }
    
    my $messages = session('messages') || undef;
    my $username = cookie('username') || undef;
    my $output  = template 'login' => {
        reset    => $reset,
        messages => $messages,
        username => $username,
        page     => 'login',
    };
    session 'messages' => [];
    $output;
};

# Dismiss a notice
get '/close/:id' => sub {
    Lenio::Notice->dismiss(var('login'), param('id'));
};

get '/error' => sub {
    my $output  = template 'error' => {
        error => param('error'),
        page  => 'error',
    };
    session 'messages' => [];
    $output;
};

any qr{^/user/?([\w]*)/?([\d]*)$} => sub {
    my ( $action, $id ) = splat;

    my $is_admin = var('login')->{is_admin};

    # Stop normal users performing admin tasks on other users
    unless ($is_admin)
    {
        $id     = var('login')->{id};
        $action = 'view';
    }

    Lenio::Login->delete(param('delete'))
        if $is_admin && param('delete');

    my @logins;
    if ( $action eq 'new' || $action eq 'view' ) {

        if ( param('submit') ) {
            my $adm = $is_admin && param('is_admin') ? 1 : 0;
            # param org_ids can be a scalar, array or undefined, depending how many where submitted
            my $org_ids = !defined param('org_ids')
                        ? []
                        : ref param('org_ids') eq 'ARRAY'
                        ? param('org_ids')
                        : [ param('org_ids') ];
            my $login = {
                username      => param('email'),
                email         => param('email'),
                firstname     => param('firstname'),
                surname       => param('surname'),
                email_comment => param('email_comment') ? 1 : 0,
                email_ticket  => param('email_ticket') ? 1 : 0,
                org_ids       => $org_ids,
                is_admin      => $adm,
            };
            $login->{id} = $id if $id;
            $login->{password} = param('password') if param('password');
            eval {Lenio::Login->new($login)};
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
                my $a = $action eq 'new' ? 'added' : 'updated';
                forwardHome({ success => "User has been successfully $a" }, 'user');
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

any qr{^/contractor/?([\w]*)/?([\d]*)$} => sub {
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

any qr{^/notice/?([\w]*)/?([\d]*)$} => sub {
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

any qr{^/ticket/?([\w]*)/?([\d]*)/?([\d]*)/?([-\d]*)$} => sub {
    my ( $action, $id, $site_id, $date ) = splat;

    my @tickets;
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
                completed      => $completed,
                planned        => $planned,
            };

            # A normal user cannot edit a ticket that has already been created,
            # unless it is related to a locally created task
            if ($action eq 'view')
            {
                forwardHome(
                    { danger => 'You do not have permission to edit this ticket' }
                ) unless var('login')->{is_admin} || $ticket->site_task->task->global == 0;
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
                Lenio::Email->send($args)
                    unless $t->site_task->task && $t->site_task->task->global == 0; # Don't email local tasks
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
    }

    my @contractors = Lenio::Contractor->all;
    my $output = template 'ticket' => {
        action      => $action,
        id          => $id,
        tickets     => \@tickets,
        contractors => \@contractors,
        messages    => session('messages'),
        login       => var('login'),
        page        => 'ticket'
    };
    session 'messages' => [];
    $output;
};

get '/attach/:file' => sub {
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

any qr{^/task/?([\w]*)/?([\d]*)$} => sub {
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

    my @tasks; my @tasks_local; my @adhocs;
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
    else
    {
        # Get all the local tasks
        @tasks_local = Lenio::Task->summary(session ('site_id') || undef, {global => 0, onlysite => 1, fy => session('fy')});
        # Get all the global tasks.
        @tasks = Lenio::Task->summary(session ('site_id') || undef, {global => 1, fy => session('fy')});
        # Get any adhoc tasks
        @adhocs = Lenio::Ticket->all(var('login'), { site_id => session ('site_id'), adhoc_only => 1, fy => session('fy') });
        $action = '';
    }

    my $output = template 'task' => {
        login       => var('login'),
        action      => $action,
        site_id     => session('site_id'),
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

get '/data' => sub {
    my $from = DateTime->from_epoch( epoch => ( param('from') / 1000 ) );
    my $to   = DateTime->from_epoch( epoch => ( param('to') / 1000 ) );
    my @tasks;
    my @sites = session('site_id')
              ? ( Lenio::Site->site( session 'site_id' ) )
              : @{var('login')->{sites}};
    foreach my $site (@sites) {
        foreach my $task ( Lenio::Task->calendar( $from, $to, $site->id, var('login') ) ) {
            my $t = Lenio::Task->calPopulate($task, $site);
            push @tasks, $t if $t;
        }
    }
    header "Cache-Control" => "max-age=0";
    { success => 1, result => \@tasks };
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

true;
