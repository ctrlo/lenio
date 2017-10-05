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

package Lenio::Email;

use Encode qw(decode encode);
use Log::Report;
use Mail::Message;
use Mail::Message::Field::Address;
use Template;
use Text::Autoformat qw(autoformat break_wrap);

use Moo;
use MooX::Types::MooseLike::Base qw/:all/;

has config => (
    is       => 'ro',
    isa      => HashRef,
    required => 1,
);

has site => (
    is       => 'ro',
    required => 1,
);

has schema => (
    is       => 'ro',
    required => 1,
);

has uri_base => (
    is       => 'ro',
    required => 1,
);

sub send($)
{   my ($self, $args) = @_;

    my $login = $args->{login} or return;
    $args->{siteurl} = $self->uri_base;

    my $template = Template->new
       ({INCLUDE_PATH => $self->config->{lenio}->{emailtemplate}});

    my $org  = sprintf("%s (%s)", $self->site->org->name, $self->site->name);
    $args->{org} = $org;

    # Will get undefined when args passed to template
    my $template_name = $args->{template};
    my $ticket        = $args->{ticket};

    my $message;
    $template->process("$template_name.tt", $args, \$message)
	or error "Template process failed: " . $template->error();
    $message = autoformat $message, {all => 1, break => break_wrap};

    my @users = $self->schema->resultset('Login')->search(
         {
             'sites.id' => $self->site->id,
             deleted    => undef,
         },
         { join    => {'login_orgs' => {'org' => 'sites' }}}
    );
    foreach my $user (@users)
    {
        if ($user->email_comment && $template_name eq 'ticket/comment'
            || ($user->email_ticket && $template_name eq 'ticket/new')
            || ($user->email_ticket && $template_name eq 'ticket/update')
        ) {
            $self->_email(
                to      => $user->email,
                subject => $args->{subject}.$org,
                message => $message,
                attach  => $args->{attach},
            ) unless
                $user->only_mine && $ticket->get_column('created_by') != $user->id # Only own tickets
                || $login->id == $user->id; # Don't alert person submitting comment
        }
    }

    # Send updates to system administrators if not an admin making the comment
    if (!$login->is_admin)
    {
        foreach my $admin ($self->schema->resultset('Login')->search({ is_admin => 1, deleted => undef }))
        {
            $self->_email(
                to      => $admin->email,
                subject => $args->{subject}.$org,
                message => $message,
                attach  => $args->{attach},
            );
        }
    }
}

sub _email
{   my ($self, %options) = @_;
    my $from = Mail::Message::Field::Address->parse($self->config->{lenio}->{email_from});
    my $sender = $self->config->{lenio}->{email_sender}
        ? Mail::Message::Field::Address->parse($self->config->{lenio}->{email_sender})
        : $from;

    my $body = Mail::Message::Body::Lines->new(
        charset  => 'utf8',
        mimetype => 'text/plain',
        data     => encode(utf8 => $options{message}),
    )->encode(
       transfer_encoding => 'Quoted-printable',
       charset           => 'utf8',
    );

    if (my $attach = $options{attach})
    {
        my $attach = Mail::Message::Body::Lines->new(
            data      => $attach->{data},
            mime_type => $attach->{mime_type},
        )->encode(
            transfer_encoding => 'base64',
        );
        $body = $body->attach($attach);
    }

    Mail::Message->buildFromBody(
        $body,
        To             => $options{to},
        From           => $from,
        Sender         => $sender,
        Subject        => $options{subject},
    )->send(
        via              => 'sendmail',
        sendmail_options => [-f => $sender->address],
    );
}

1;
