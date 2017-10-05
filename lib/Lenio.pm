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
use DateTime::Format::Strptime;
use JSON qw(encode_json);
use Lenio::Calendar;
use Lenio::Email;
use Text::CSV;

use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Extensible;
use Dancer2::Plugin::LogReport;

set behind_proxy => config->{behind_proxy};

our $VERSION = '0.1';

# There should never be exceptions from DBIC, so we want to panic them to
# ensure they get notified at the correct level.
schema->exception_action(sub {
    # Older versions of DBIC use this handler during expected exceptions.
    # Temporary hack: do not panic these as DBIC does not catch them
    die $_[0] if $_[0] =~ /^Unable to satisfy requested constraint/; # Expected
    panic @_; # Not expected
});

my $dateformat = config->{lenio}->{dateformat};

hook before => sub {

    # Used to display error messages
    return if param 'error';

    my $user = logged_in_user
        or return;

    my $login = rset('Login')->find($user->{id});

    # Do not try and get sites etc if logging out. User may have received "no
    # sites associated" error and be trying to logout, in which case we don't
    # want to run the following code as it will generate errors
    return if request->uri eq '/logout';

    # Sites associated with the user 
    forward '/error', { 'error' => 'There are no sites associated with this username' }
        unless $login->sites;
 
    # Select individual site and check user has access
    if ( param('site') && param('site') eq 'all' ) {
        session site_id => '';
    }
    elsif ( param('site') ) {
        session site_id => param('site')
            if $login->has_site(param('site'));
    }
    session(site_id => ($login->sites)[0]->id) unless (defined session('site_id'));

    session 'fy' => param('fy') if param('fy');
    session 'fy' => Lenio::FY->new(site_id => session('site_id'), schema => schema)->year
        if !session('fy');

    var login => $login;
};

hook before_template => sub {
    my $tokens = shift;

    my $base = $tokens->{base} || request->base;
    $tokens->{url}->{css}  = "${base}css";
    $tokens->{url}->{js}   = "${base}js";
    $tokens->{url}->{page} = $base;
    $tokens->{url}->{page} =~ s!.*/!!; # Remove trailing slash
    $tokens->{scheme}    ||= request->scheme; # May already be set for phantomjs requests
    $tokens->{hostlocal}   = config->{gads}->{hostlocal};

    $tokens->{messages} = session('messages');
    $tokens->{login}    = var('login');
};

get '/' => require_login sub {

    # Deal with sort options
    if (param 'sort')
    {
        session task_desc => session('task_sort') && session('task_sort') eq param('sort') ? !session('task_desc') : 0;
        session task_sort => param('sort');
    }

    my $local = var('login')->is_admin ? 0 : 1; # Only show local tasks for non-admin
    my $sites = var('login')->is_admin
              ? session('site_id')
              : session('site_id') ? session('site_id') : var('login')->sites;
    my @overdue = rset('Task')->overdue(
        site_id   => $sites,
        local     => $local,
        sort      => session('task_sort'),
        sort_desc => session('task_desc'),
    );
    template 'index' => {
        dateformat => config->{lenio}->{dateformat},
        tasks      => \@overdue,
        page       => 'index'
    };
};

sub login_page_handler
{
    my $messages = session('messages') || undef;
    success __"A password reset request has been sent if the email address
           entered was valid" if defined param('reset_sent');
    if (defined param('login_failed'))
    {
        status 401;
        report {is_fatal=>0}, ERROR => "Username or password not valid";
    }
    template login => {
        page                => 'login',
        new_password        => request->parameters->get('new_password'),
        password_code_valid => request->parameters->get('password_code_valid'),
        reset_code          => request->parameters->get('new_password') || request->parameters->get('password_code_valid'),
    };
}

# Dismiss a notice
get '/close/:id' => require_login sub {
    my $notice = rset('LoginNotice')->find(param 'id') or return;
    $notice->delete if $notice->login_id == var('login')->id;
};

get '/error' => require_login sub {
    template 'error' => {
        error => param('error'),
        page  => 'error',
    };
};

any '/user/:id' => require_login sub {

    my $is_admin = var('login')->is_admin;
    my $id       = $is_admin ? route_parameters->get('id') : var('login')->id;

    my $email_comment = param('email_comment') ? 1 : 0;
    my $email_ticket  = param('email_ticket') ? 1 : 0;
    my $only_mine  = param('only_mine') ? 1 : 0;
    if (!$id && $is_admin && param('submit'))
    {
        my $email = param('email')
            or error "Please enter an email address for the new user";
        # check existing
        rset('Login')->active_rs->search({ email => $email })->count
            and error __x"The email address {email} already exists", email => $email;
        my $newuser = create_user username => $email, email => $email, realm => 'dbic', email_welcome => 1;
        $id = $newuser->{id};
        # Default to on
        $email_comment = 1;
        $email_ticket  = 1;
    }

    my $login    = $id && rset('Login')->find($id);
    $id && !$login and error "User ID {id} not found", id => $id;

    if ($is_admin && param('delete'))
    {
        if (process sub { $login->disable })
        {
            forwardHome({ success => "User has been deleted successfully" }, '/users');
        }
    }

    if (param 'submit') {
        $login->username(param 'email');
        $login->email(param 'email');
        $login->firstname(param 'firstname');
        $login->surname(param 'surname');
        $login->email_comment($email_comment);
        $login->email_ticket($email_ticket);
        $login->only_mine($only_mine);

        if ($is_admin && !$login->is_admin)
        {
            $login->is_admin(param('is_admin') ? 1 : 0);
            my @org_ids = body_parameters->get_all('org_ids');
            $login->update_orgs(@org_ids);
        }
        if (process sub { $login->update_or_insert } )
        {
            my $forward = $is_admin ? 'users' : '';
            forwardHome({ success => "User has been submitted successfully" }, $forward);
        }
    }

    my @orgs = rset('Org')->all;
    template 'user' => {
        id         => $id,
        orgs       => \@orgs,
        edit_login => $login,
        page       => 'user'
    };
};

get '/users/?' => require_login sub {

    var('login')->is_admin
        or error "You do not have access to this page";

    template 'users' => {
        logins    => [rset('Login')->active],
        page      => 'user'
    };
};

any '/contractor/?:id?' => require_login sub {

    var('login')->is_admin
        or forwardHome({ danger => 'You do not have permission to view contractors' });

    my $contractor;
    my $id = route_parameters->get('id');
    if (defined $id)
    {
        $contractor = rset('Contractor')->find($id) || rset('Contractor')->new({});
    }

    if (param('delete'))
    {
        if (process (sub { $contractor->delete } ) )
        {
            forwardHome({ success => 'Contractor has been successfully deleted' }, 'contractor');
        }
    }

    if (param 'submit')
    {
        $contractor->name(param 'name');
        if (process sub { $contractor->update_or_insert })
        {
            forwardHome({ success => 'Contractor has been successfully added' }, 'contractor');
        }
    }

    template 'contractor' => {
        id          => $id,
        contractor  => $contractor,
        contractors => [rset('Contractor')->ordered],
        page        => 'contractor'
    };
};

any '/notice/?:id?' => require_login sub {

    var('login')->is_admin
        or forwardHome({ danger => 'You do not have permission to view notice settings' });

    my $id = route_parameters->get('id');
    my $notice = defined $id && (rset('Notice')->find($id) || rset('Notice')->new({}));

    if (param('delete'))
    {
        if (process (sub { $notice->delete } ) )
        {
            forwardHome({ success => 'The notice has been successfully deleted' }, 'notice');
        }
    }

    if (param 'submit')
    {
        $notice->text(param 'text');
        if (process sub { $notice->update_or_insert })
        {
            forwardHome({ success => 'The notice has been successfully created' }, 'notice');
        }
    }

    template 'notice' => {
        id      => $id,
        notice  => $notice,
        notices => [rset('Notice')->all_with_count],
        page    => 'notice'
    };
};
 
any '/check_edit/:id' => require_login sub {

    my $id = route_parameters->get('id');

    my $check = ($id && rset('Task')->find($id)) || rset('Task')->new({ site_check => 1, global => 0 });

    my $site_id = ($check && ($check->site_tasks)[0] && ($check->site_tasks)[0]->site_id) || param('site_id');
    error "You do not have access to this check"
        unless var('login')->has_site($site_id);

    if (param 'submitcheck')
    {
        if (my $ci = param('checkitem'))
        {
            if (process sub { rset('CheckItem')->create({ task_id => $id, name => $ci }) } )
            {
                forwardHome(
                    { success => 'The check item has been added successfully' }, "check_edit/$id" );
            }
        }
        else {
            $check->name(param 'name');
            $check->description(param 'description');
            $check->period_qty(param 'period_qty');
            $check->period_unit(param 'period_unit');
            $check->set_site_id(param 'site_id');
            if (process sub { $check->update_or_insert })
            {
                forwardHome(
                    { success => 'The site check has been successfully updated' }, 'task' );
            }
        }
    }

    if (param 'delete')
    {
        if (process sub { $check->delete })
        {
            forwardHome(
                { success => 'The check has been successfully deleted' }, 'task' );
        }
    }

    template 'check_edit' => {
        check       => $check,
        site_id     => session('site_id'),
        page        => 'check_edit'
    };
};

any '/checks/?' => require_login sub {

    my $site_id = session 'site_id'
        or error __"Please select a site before viewing site checks";

    template 'checks' => {
        site        => rset('Site')->find(session 'site_id'),
        site_checks => [rset('Task')->site_checks($site_id)],
        dateformat  => config->{lenio}->{dateformat},
        page        => 'check',
    };
};

any '/check/?:task_id?/?:check_done_id?/?' => require_login sub {

    my $task_id       = route_parameters->get('task_id');
    my $check_done_id = route_parameters->get('check_done_id');
    my $check         = rset('Task')->find($task_id);

    my $site_id = session 'site_id'
        or error __"Please select a site before viewing site checks";

    my $check_done = $check_done_id ? rset('CheckDone')->find($check_done_id) : rset('CheckDone')->new({});

    my $check_site_id = ($check->site_tasks)[0]->site_id;
    error "You do not have access to this check"
        unless var('login')->has_site($check_site_id);

    if (param 'submit_check_done')
    {
        my $site_task_id = $check_done_id ? $check_done->site_task_id : rset('SiteTask')->search({
            task_id => $task_id,
            site_id => $site_id,
        })->next->id;
        # Log the completion of a site check
        # Check user has permission first
        error __x"You do not have permission for site ID {id}", id => $site_id
            unless var('login')->has_site_task( $site_task_id );

        my $datetime = _to_dt(param 'completed') || DateTime->now;

        $check_done->datetime($datetime);
        $check_done->comment(param 'comment');
        $check_done->site_task_id($site_task_id);
        $check_done->login_id(var('login')->id);
        $check_done->update_or_insert;

        my $params = params;
        foreach my $key (keys %$params)
        {
            next unless $key =~ /^item([0-9]+)/;
            my $check_item_id = $1;
            my $check_item_done = rset('CheckItemDone')->update_or_create({
                check_item_id => $check_item_id,
                check_done_id => $check_done->id,
                status        => param("item$check_item_id"),
            });
        }
        forwardHome({ success => "Check has been recorded successfully" }, 'checks');
    }

    template 'check' => {
        check       => rset('Task')->find($task_id),
        check_done  => $check_done,
        dateformat  => config->{lenio}->{dateformat},
        page        => 'check',
    };
};

get '/ticket/view/:id?' => require_login sub {
    my $id = param 'id';
    redirect '/ticket'
        unless $id =~ /^[0-9]+$/;
    redirect "/ticket/$id";
};

any '/ticket/:id?' => require_login sub {

    my $date    = query_parameters->get('date');
    my $id      = route_parameters->get('id');

    # Check for comment deletion
    if (my $comment_id = body_parameters->get('delete_comment'))
    {
        error "You do not have access to delete comments"
            unless var('login')->is_admin;
        if (my $comment = rset('Comment')->find($comment_id))
        {
            my $ticket_id = $comment->ticket_id;
            if (process sub { $comment->delete })
            {
                forwardHome({ success => "Comment has been successfully deleted" }, "ticket/$ticket_id");
            }
        }
        else {
            error "Comment id {id} not found", id => $comment_id;
        }
    }

    # task_id can be specified in posted form or prefilled in ticket url
    my $task;
    if (my $task_id = body_parameters->get('task_id') || query_parameters->get('task_id'))
    {
        $task = rset('Task')->find($task_id);
    }

    my $ticket;
    if (defined($id) && $id)
    {
        $ticket = rset('Ticket')->find($id);
        # Check whether the user has access to this ticket
        error __x"You do not have permission for ticket ID {id}", id => $id
            unless var('login')->has_site($ticket->site_id);
        # Existing ticket, get task from DB
        $task = $ticket->task;
    }
    elsif (defined($id) && !param('submit'))
    {
        # If applicable, Prefill ticket fields with initial values based on task
        if ($task)
        {
            my $sid  = $task->site_task_local && $task->site_task_local->site_id; # site_id associated with local task
            # See if the user has permission to view associated task
            if ( var('login')->is_admin
                || (!$task->global && var('login')->has_site($sid))
            ) {
                $ticket = rset('Ticket')->new({
                    name        => $task->name,
                    description => $task->description,
                    planned     => $date,
                    local_only  => $task->global ? 0 : 1,
                    task_id     => $task->id,
                    site_id     => query_parameters->get('site_id') || session('site_id'),
                });
            }
        }
        else {
            $ticket = rset('Ticket')->new({
                site_id => query_parameters->get('site_id') || session('site_id'),
            });
        }
    }
    elsif (defined($id))
    {
        # New ticket submitted, create base object to be updated
        $ticket = rset('Ticket')->new({
            created_by => logged_in_user->{id},
        });
    }

    if ( param('attach') ) {
        my $file = request->upload('newattach');
        my $attach = {
            name        => $file->basename,
            ticket_id   => $id,
            content     => $file->content,
            mimetype    => $file->type,
        };

        if (process sub { rset('Attach')->create($attach) })
        {
            my $args = {
                login    => var('login'),
                template => 'ticket/attach',
                ticket   => $ticket,
                url      => "/ticket/".$ticket->id,
                subject  => "Ticket ".$ticket->id." attachment added - ",
                attach   => {
                    data      => $file->content,
                    mime_type => $file->type,
                },
            };
            my $email = Lenio::Email->new(
                config   => config,
                schema   => schema,
                uri_base => request->uri_base,
                site     => $ticket->site, # rset('Site')->find(param 'site_id'),
            );
            $email->send($args);
            success __"File has been added successfully";
        }
    }

    if ( param('attachrm') ) {
        error __"You do not have permission to delete attachments"
            unless var('login')->is_admin;

        if (process sub { rset('Attach')->find(param 'attachrm')->delete })
        {
            success __"Attachment has been deleted successfully";
        }
    }

    if (param 'delete')
    {
        error __"You do not have permission to delete this ticket"
            unless var('login')->is_admin || $ticket->local_only;
        if (process sub { $ticket->delete })
        {
            forwardHome({ success => "Ticket has been successfully deleted" }, 'tickets');
        }
    }

    # Comment can be added on ticket creation or separately.  Create the
    # object, which will be added at ticket insertion time or otherwise later.
    my $comment = param('comment')
        && rset('Comment')->new({
            text      => param('comment'),
            login_id  => var('login')->id,
            datetime  => DateTime->now,
        });

    if (param 'submit')
    {
        # Find out if this is related to locally created task.
        # If so, allow dates to be input
        my $global = $task && $task->global;

        my $completed = (var('login')->is_admin || !$global) && _to_dt(param('completed'));
        my $planned   = (var('login')->is_admin || !$global) && _to_dt(param('planned'));

        $ticket->name(param 'name');
        $ticket->description(param 'description');
        $ticket->contractor_invoice(param 'contractor_invoice');
        $ticket->contractor_id(param 'contractor');
        $ticket->cost_planned(param 'cost_planned');
        $ticket->cost_actual(param 'cost_actual');
        $ticket->local_only(param 'local_only');
        $ticket->report_received(param('report_received') ? 1 : 0);
        $ticket->invoice_sent(param('invoice_sent') ? 1 : 0);
        $ticket->completed($completed);
        $ticket->planned($planned);
        $ticket->task_id($task && $task->id);
        $ticket->site_id(param('site_id'));

        # A normal user cannot edit a ticket that has already been created,
        # unless it is related to a locally created task
        if ($id)
        {
            error __"You do not have permission to edit this ticket"
                unless var('login')->is_admin || $ticket->local_only;
        }

        my $was_local = $id && $ticket->local_only; # Need old setting to see if to send email
        if (process sub { $ticket->update_or_insert })
        {
            # XXX Ideally the comment would be written as a relationship
            # at the same time as the ticket, but I couldn't get it to
            # work ($ticket->comments([ .. ]) appears to do nothing)
            if ($comment)
            {
                $comment->ticket_id($ticket->id);
                $comment->insert;
            }
            my $template; my $subject; my $status;
            if ($id)
            {
                $template = 'ticket/update';
                $subject  = "Ticket ".$ticket->id." updated - ";
                $status   = 'updated';
            }
            else {
                $template = 'ticket/new';
                $subject  = "New ticket ID ".$ticket->id." - ";
                $status   = 'created';
            }
            my $args = {
                login       => var('login'),
                template    => $template,
                ticket      => $ticket,
                url         => "/ticket/".$ticket->id,
                subject     => $subject,
            };
            # Assume send update to admin
            my $send_email = 1;
            # Do not send email update if new ticket and local, or was local_only and still is local only
            $send_email = 0 if ((!$id && $ticket->local_only) || ($id && $ticket->local_only && $was_local));
            # Do not send email if local site task
            $send_email = 0 if $task && !$task->global;
            if ($send_email)
            {
                my $email = Lenio::Email->new(
                    config   => config,
                    schema   => schema,
                    uri_base => request->uri_base,
                    site     => rset('Site')->find(param 'site_id'),
                );
                $email->send($args);
            }
            forwardHome(
                { success => "Ticket ".$ticket->id." has been successfully $status" }, 'ticket/'.$ticket->id );
        }
    }

    if (param 'addcomment')
    {
        $comment->ticket_id($ticket->id);
        if (process sub { $comment->insert })
        {
            my $args = {
                login       => var('login'),
                template    => 'ticket/comment',
                url         => "/ticket/$id",
                ticket      => $ticket,
                subject     => "Ticket ".$ticket->id." updated - ",
                comment     => param('comment'),
            };
            my $email = Lenio::Email->new(
                config   => config,
                schema   => schema,
                uri_base => request->uri_base,
                site     => rset('Site')->find($ticket->site_id),
            );
            $email->send($args);
        }
    }

    template 'ticket' => {
        id           => $id,
        ticket       => $ticket,
        contractors  => [rset('Contractor')->ordered],
        page         => 'ticket'
    };
};

get '/tickets/?' => require_login sub {

    # Deal with sort options
    if (param 'sort')
    {
        session ticket_desc => session('ticket_sort') && session('ticket_sort') eq param('sort') ? !session('ticket_desc') : 0;
        session ticket_sort => param('sort');
    }

    # Set filtering of tickets based on drop-down
    if (defined param('task_tickets'))
    {
        my $tt = param('task_tickets');
        my $task_tickets = $tt eq 'all'
            ? 'all'
            : $tt eq 'tasks'
            ? 'tasks'
            : 'reactive';
        session task_tickets => $task_tickets;
    }
    elsif (!session('task_tickets'))
    {
        session 'task_tickets' => 'reactive'; # Default to only reactionary
    }

    my $task_tickets = session('task_tickets') eq 'all'
                     ? undef
                     : session('task_tickets') eq 'tasks'
                     ? 1
                     : 0;

    my $task = param('task_id') && rset('Task')->find(param 'task_id');

    my $uncompleted_only; my $task_id;
    if (param('task_id'))
    {
        $uncompleted_only = 0;
        $task_id          = param('task_id');
    }
    else {
        $uncompleted_only = 1;
    }
    my @tickets = rset('Ticket')->summary(
        login            => var('login'),
        site_id          => session('site_id'),
        uncompleted_only => $uncompleted_only,
        sort             => session('ticket_sort'),
        sort_desc        => session('ticket_desc'),
        task_id          => $task_id,
        task_tickets     => $task_id ? undef : $task_tickets,
    );

    template 'tickets' => {
        task         => $task, # Tickets related to task
        tickets      => \@tickets,
        sort         => session('ticket_sort'),
        sort_desc    => session('ticket_desc'),
        dateformat   => config->{lenio}->{dateformat},
        task_tickets => session('task_tickets'),
        page         => 'ticket'
    };
};

get '/attach/:file' => require_login sub {
    my $file = rset('Attach')->find(param 'file')
        or error __x"File ID {id} not found", id => param('file');
    my $data = $file->content;
    my $site_id = $file->ticket->site_id;
    if ( var('login')->has_site($site_id))
    {
        send_file( \$data, content_type => $file->mimetype );
    } else {
        forwardHome(
            { danger => 'You do not have permission to view this file' } );
    }
};

any '/invoice/:id' => require_login sub {

    my $id      = route_parameters->get('id');
    my $invoice = defined $id && (rset('Invoice')->find($id) || rset('Invoice')->new({}));
    my $ticket  = query_parameters->get('ticket') && rset('Ticket')->find(query_parameters->get('ticket'));

    if (defined query_parameters->get('download'))
    {
        my %options = %{config->{lenio}->{invoice}};
        $options{dateformat} = config->{lenio}->{dateformat};
        my $pdf = $invoice->pdf(%options);
	return send_file(
	    \$pdf,
	    content_type => 'application/pdf',
	    filename     => (config->{lenio}->{invoice}->{prefix}).$invoice->id.".pdf",
	);
    }

    var('login')->is_admin
        or forwardHome({ danger => 'You do not have permission to edit invoices' });

    if (param('delete'))
    {
        if (process (sub { $invoice->delete } ) )
        {
            forwardHome({ success => 'The invoice has been successfully deleted' }, 'invoices');
        }
    }

    if (param 'submit')
    {
        $invoice->description(body_parameters->get('description'));
        $invoice->number(body_parameters->get('number'));
        $invoice->disbursements(body_parameters->get('disbursements'));
        $invoice->ticket_id($ticket->id)
            if $ticket;
        $invoice->datetime(DateTime->now)
            if !$id;
        if (process sub { $invoice->update_or_insert })
        {
            # Email new invoice to users
            my %options = %{config->{lenio}->{invoice}};
            $options{dateformat} = config->{lenio}->{dateformat};
            my $pdf = $invoice->pdf(%options);
            my $args = {
                login    => var('login'),
                template => 'ticket/invoice',
                ticket   => $ticket,
                url      => "/ticket/".$ticket->id,
                subject  => "Ticket ".$ticket->id." invoice added - ",
                attach   => {
                    data      => $pdf,
                    mime_type => 'application/pdf',
                },
            };
            my $email = Lenio::Email->new(
                config   => config,
                schema   => schema,
                uri_base => request->uri_base,
                site     => $ticket->site, # rset('Site')->find(param 'site_id'),
            );
            $email->send($args);

            my $action = $id ? 'updated' : 'created';
            $id = $invoice->id;
            forwardHome({ success => "The invoice has been successfully $action" }, "invoice/$id");
        }

    }

    template 'invoice' => {
        id      => $id,
        invoice => $invoice,
        ticket  => $ticket,
        page    => 'invoice'
    };
};

any '/invoices' => require_login sub {

    if (param 'sort')
    {
        session invoice_desc => session('invoice_sort') && session('invoice_sort') eq param('sort') ? !session('invoice_desc') : 0;
        session invoice_sort => param('sort');
    }

    my @invoices = rset('Invoice')->summary(
        login     => var('login'),
        site_id   => session('site_id'),
        sort      => session('invoice_sort'),
        sort_desc => session('invoice_desc'),
    );

    template 'invoices' => {
        invoices => \@invoices,
        page     => 'invoice'
    };
};

any '/task/?:id?' => require_login sub {

    my $action;
    my $id = route_parameters->get('id');

    if (var('login')->is_admin)
    {
        if (param 'taskadd')
        {
            rset('SiteTask')->find_or_create({ task_id => param('taskadd'), site_id => session('site_id') });
        }
        if (param 'taskrm')
        {
            rset('SiteTask')->search({ task_id => param('taskrm'), site_id => session('site_id') })->delete;
        }
    }

    my $task = defined($id) && ($id && rset('Task')->find($id) || rset('Task')->new({}));

    my @tasks; my @tasks_local; my @adhocs;

    if ($task && $task->id)
    {
        # Check whether the user has access to this task
        my @sites = map { $_->site_id } $task->site_tasks->all;
        forwardHome(
            { danger => "You do not have permission for service item $id" } )
                unless var('login')->is_admin || (!$task->global && var('login')->has_site(@sites));
    }

    if (param 'delete')
    {
        my $site_id = $task->site_task_local && $task->site_task_local->site_id; # Site ID for local tasks
        if (var('login')->is_admin)
        {
            if (process sub { $task->delete })
            {
                    forwardHome({ success => 'Service item has been successfully deleted' }, 'task' );
            }
        }
        elsif (var('login')->has_site($site_id))
        {
            if (process sub { $task->delete })
            {
                    forwardHome({ success => 'Service item has been successfully deleted' }, 'task' );
            }
        }
        else {
            error __x"You do not have permission to delete task ID {id}", id => $id;
        }
    }

    if ( var('login')->is_admin && param('tasktype_add') )
    {
        if (process sub { rset('Tasktype')->create({name => param('tasktype_name')}) })
        {
            forwardHome(
                { success => 'Task type has been added' }, "task/$id" );
        }
    }

    if ( param('submit') ) {

        if (var('login')->is_admin)
        {
            $task->global(1);
        }
        else
        {
            $task->set_site_id(param 'site_id');
            $task->global(0);
        }

        $task->name(param 'name');
        $task->description(param 'description');
        $task->tasktype_id(param('tasktype_id') || undef); # Fix empty string from form
        $task->period_qty(param 'period_qty');
        $task->period_unit(param 'period_unit');

        if (process sub { $task->update_or_insert })
        {
                forwardHome({ success => 'Service item has been successfully created' }, 'task' );
        }
    }

    else
    {
        my $csv = (session('site_id') && param('csv')) || ""; # prevent warnings. not for all sites
        if ($csv eq 'service')
        {

            my $csvout = rset('Task')->csv(
                site_id    => session('site_id'),
                global     => 1,
                fy         => session('fy'),
                dateformat => $dateformat,
            );

            my $now = DateTime->now->ymd;
            my $site = rset('Site')->find(session 'site_id')->org->name;
            # XXX Is this correct? We can't send native utf-8 without getting the error
            # "Strings with code points over 0xFF may not be mapped into in-memory file handles".
            # So, encode the string (e.g. "\x{100}"  becomes "\xc4\x80) and then send it,
            # telling the browser it's utf-8
            utf8::encode($csvout);
            return send_file(
                \$csvout,
                content_type => 'text/csv; chrset="utf-8"',
                filename     => "$site service items $now.csv"
            );
        }

        # Get all the global tasks.
        @tasks = rset('Task')->summary(site_id => session('site_id'), global => 1, fy => session('fy'));

        # Get any adhoc tasks
        @adhocs = rset('Ticket')->summary(
            login        => var('login'),
            site_id      => session('site_id'),
            task_tickets => 0,
            fy           => session('site_id') && session('fy'),
        );
        if ($csv eq 'reactive')
        {
            my $csv = Text::CSV->new;
            my @headings = qw/title cost_planned cost_actual completed contractor/;
            $csv->combine(@headings);
            my $csvout = $csv->string."\n";
            my ($cost_planned_total, $cost_actual_total);
            foreach my $adhoc (@adhocs)
            {
                my @row = (
                    $adhoc->name,
                    $adhoc->cost_planned,
                    $adhoc->cost_actual,
                    $adhoc->completed && $adhoc->completed->strftime($dateformat),
                    $adhoc->contractor && $adhoc->contractor->name,
                );
                $csv->combine(@row);
                $csvout .= $csv->string."\n";
                $cost_planned_total += ($adhoc->cost_planned || 0);
                $cost_actual_total  += ($adhoc->cost_actual || 0);
            }
            $csv->combine('Totals:', sprintf("%.2f", $cost_planned_total), sprintf("%.2f", $cost_actual_total),'','');
            $csvout .= $csv->string."\n";
            my $now = DateTime->now->ymd;
            my $site = rset('Site')->find(session 'site_id')->org->name;
            utf8::encode($csvout); # See comment above
            return send_file(
                \$csvout,
                content_type => 'text/csv; chrset="utf-8"',
                filename     => "$site reactive $now.csv"
            );
        }
        # Get all the local tasks
        @tasks_local = rset('Task')->summary(site_id => session('site_id'), global => 0, onlysite => 1, fy => session('fy'));
        $action = '';
    }

    template 'task' => {
        dateformat       => $dateformat,
        action           => $action,
        site             => rset('Site')->find(session 'site_id'),
        site_checks      => [rset('Task')->site_checks(session 'site_id')],
        task             => $task,
        tasks            => \@tasks,
        tasks_local      => \@tasks_local,
        task_completed   => rset('Task')->last_completed(site_id => session('site_id'), global => 1),
        tasktypes        => [rset('Tasktype')->all],
        adhocs           => \@adhocs,
        page             => 'task'
    };
};

get '/data' => require_login sub {

    my $utc_offset = param('utc_offset') * -1; # Passed from calendar plugin as query parameter
    my $from  = DateTime->from_epoch( epoch => ( param('from') / 1000 ) )->add( minutes => $utc_offset );
    my $to    = DateTime->from_epoch( epoch => ( param('to') / 1000 ) )->add(minutes => $utc_offset );

    my @tasks;
    my @sites = session('site_id')
              ? ( rset('Site')->find( session 'site_id' ) )
              : var('login')->sites;
    foreach my $site (@sites) {
        my $calendar = Lenio::Calendar->new(
            from   => $from,
            to     => $to,
            site   => $site,
            login  => var('login'),
            schema => schema,
        );
        push @tasks, $calendar->tasks;
        push @tasks, $calendar->checks;
    }
    _send_json ({
        success => 1,
        result => \@tasks
    });
};

sub forwardHome {
    my ($message, $page, %options) = @_;

    if ($message)
    {
        my ($type) = keys %$message;
        my $lroptions = {};
        # Check for option to only display to user (e.g. passwords)
        $lroptions->{to} = 'error_handler' if $options{user_only};

        if ($type eq 'danger')
        {
            $lroptions->{is_fatal} = 0;
            report $lroptions, ERROR => $message->{$type};
        }
        else {
            report $lroptions, NOTICE => $message->{$type}, _class => 'success';
        }
    }
    $page ||= '';
    redirect "/$page";
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

sub _to_dt
{   my $parser = DateTime::Format::Strptime->new(
         pattern   => '%Y-%m-%d',
         time_zone => 'local',
    );
    $parser->parse_datetime(shift);
}

true;
