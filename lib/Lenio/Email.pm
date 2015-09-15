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

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
schema->storage->debug(1);
use Mail::Message;
use Mail::Message::Field::Address;
use Text::Autoformat qw(autoformat break_wrap);
use utf8;

sub send($)
{   my ($class, $args) = @_;

    my $login = $args->{login} or return;
    my $site_id = $args->{site_id} or return;
    $args->{siteurl} = request->uri_base;

    my $template = Template->new
       ({INCLUDE_PATH => config->{lenio}->{emailtemplate}});

    my $site = Lenio::Site->site($site_id);
    my $org  = sprintf("%s (%s)", $site->org->name, $site->name);
    $args->{org} = $org;

    # Will get undefined when args passed to template
    my $template_name = $args->{template};

    my $message;
    $template->process("$template_name.tt", $args, \$message)
	or error "Template process failed: " . $template->error();
    $message = autoformat $message, {all => 1, break=>break_wrap};

    if ($login->{is_admin})
    {
        my @users = rset('Login')->search(
             { 'sites.id' => $site_id },
             { join    => {'login_orgs' => {'org' => 'sites' }}}
        );
        foreach my $user (@users)
        {
            if ($user->email_comment && $template_name eq 'ticket/comment'
                || $user->email_ticket && $template_name eq 'ticket/new'
                || $user->email_ticket && $template_name eq ' ticket/update'
            ) {
                _email(
                    to      => $user->email,
                    subject => $args->{subject}.$org,
                    message => $message,
                );
            }
        }
    }
    else
    {
        foreach my $admin (rset('Login')->search({ is_admin => 1 }))
        {
            _email(
                to      => $admin->email,
                subject => $args->{subject}.$org,
                message => $message
            );
        }
    }
}

sub _email
{   my (%options) = @_;
    my $from = Mail::Message::Field::Address->parse(config->{lenio}->{email_from});
    my $sender = config->{lenio}->{email_sender}
        ? Mail::Message::Field::Address->parse(config->{lenio}->{email_sender})
        : $from;

    utf8::decode($options{message});
    my $body = Mail::Message::Body::Lines->new(
        data => $options{message},
    );

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
