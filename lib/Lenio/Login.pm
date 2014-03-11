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

package Lenio::Login;

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use Dancer2::Plugin::Emailesque;
use Ouch;
use String::Random;
use Text::Autoformat qw(autoformat break_wrap);
use Crypt::SaltedHash;
use Email::Valid;
schema->storage->debug(1);

use Lenio::Schema;

sub login($)
{   my ($class, $args) = @_;
    if ($args->{id})
    {
        rset('Login')->find($args->{id});
    }
    elsif ($args->{username})
    {
        my $login = rset('Login')->search({ username => $args->{username} })
            or ouch 'dbfail', "There was a database error when retrieving the user";
        $login->count
            or ouch 'notfound', "The requested user could not be found";
        my ($l) = $login->all;
        Crypt::SaltedHash->validate($l->password, $args->{'password'})
            or ouch 'wrongpwd', "The password entered is incorrect";
        $l;
    }
    else
    {
        ouch 'badparams', "Neither a user ID nor username were supplied";
    }
}

sub new($)
{   my ($class, $login) = @_;
    my @errors;
    $login->{username}  or push @errors, "Please enter a username";
    $login->{email}     or push @errors, "Please enter an email address";
    $login->{firstname} or push @errors, "Please enter a firstname";
    $login->{surname}   or push @errors, "Please enter a surname";
    Email::Valid->address($login->{email})
        or push @errors, "Please enter a valid email address";

    ouch 'invalid', "There were some errors in the data supplied", \@errors
        if @errors;

    $login->{password} = password($login->{password}) if $login->{password};
    my $org_ids = delete $login->{org_ids};
    my @org_new = @$org_ids;

    my $login_id;
    if ($login->{id})
    {
        my $l = rset('Login')->find($login->{id})
            or ouch 'notfound', "The requested user cannot be found";
        $l->update($login)
            or ouch 'dbfail', "There was a database error creating the user";
        $login_id = $login->{id};
    } else
    {
        ouch 'exists', "The username already exists"
            if rset('Login')->search({ username => $login->{username} })->count;
        ouch 'exists', "The email address already exists"
            if rset('Login')->search({ email => $login->{email} })->count;
        $login_id = rset('Login')->create($login)
            or ouch 'dbfail', "There was a database error when creating the user";
    }

    # Update organisation membership
    my $guard = schema->txn_scope_guard;
    my @org_old = rset('LoginOrg')->search({ login_id => $login_id })->all;
    # Delete organisation memberships that are no longer needed
    foreach my $org_old (@org_old)
    {
        rset('LoginOrg')->search({ login_id => $login_id, org_id => $org_old->org_id })->delete
            unless grep { $org_old->org_id == $_ } @org_new;
    }
    # Add organisation memberships that are not already there
    foreach my $org_new (@org_new)
    {
        rset('LoginOrg')->create({ login_id => $login_id, org_id => $org_new })
            unless grep { $org_new == $_->org_id } @org_old;
    }
    $guard->commit;
    1;
}

sub delete($)
{   my ($class, $id) = @_;
    my $l = rset('Login')->find($id) or return;
    $l->delete;
}

sub view($)
{   my ($class, $id) = @_;
    rset('Login')->find($id);
}

sub all
{   my $class = shift;
    rset('Login')->search;
}

sub hasSite($$;$)
{   my ($class, $login, @site_ids) = @_;
    return 1 if $login->{is_admin};
    foreach my $site_id (@site_ids)
    {
        return 1 if grep { $_->id == $site_id } @{$login->{sites}};
    }
}

sub resetNew($$)
{   my ($class, $code) = @_;
    my $login = rset('Login')->search({ pwdreset => $code }) or return;
    my $self = bless {}, $class;
    $self->{login} = $login;
    $self->{code}  = $code;
    $self;
}

# Return value from this function is 1 or 0 depending on whether
# to display the password reset page. On success, 0 is returned, as
# the password reset page should not be displayed
sub resetProcess($$)
{   my ($class, $args) = @_;
    $args->{code}
        or ouch 'nocode', "Please provide a password reset code";
    my $login = rset('Login')->search({ pwdreset => $args->{code} })
        or ouch 'dbfail', "There was a database error accessing the code provided";
    $login->count
        or ouch 'notfound', "The password reset code was not found";
    # If a new password wasn't provided, then we just check the
    # code (above) and return. This can be used to validate the code provided
    return 1 unless ($args->{password});
    $args->{password} eq $args->{password2}
        or ouch 'nomatch', "The 2 passwords entered do not match";
    my $password = password($args->{password});
    return 0 if $login->update({ password => $password, pwdreset => undef });
    ouch 'dbfail', "Failed to update the new password in the database";
}

sub resetRequest($)
{   my ($class, $email) = @_;
    $email or return;
    my $random = String::Random->new;
    my $reset  = $random->randregex('[A-Za-z]{32}');
    my $login  = rset('Login')->search({ email => $email }) or return;
    $login->update({ pwdreset => $reset }) or return;
    my $link    = config->{siteurl}."/login?reset=$reset";
    my $message = <<__MSG;
A request to reset your Lenio password was recently received.
Please use the following link to reset the password: $link

If you did not make this request, please ignore and delete this email.
__MSG
    $message = autoformat $message, {all => 1, break=>break_wrap};
    email {
        to      => $email,
        subject => "Lenio password reset request",
        message => $message,
    };
    return 1; # For some reason, email() does not return true on success
}

# Returns an encrypted password
sub password($)
{
    my $crypt=Crypt::SaltedHash->new(algorithm=>'SHA-512');
    $crypt->add(shift);
    $crypt->generate;
}

1;
