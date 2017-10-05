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

use Dancer2;
use Dancer2::Plugin::DBIC;
use Ouch;
use String::Random;
use Text::Autoformat qw(autoformat break_wrap);
use Crypt::SaltedHash;

use Lenio::Schema;

sub update_orgs
{   my ($class, $username, $org_ids) = @_;
    my $guard = schema->txn_scope_guard;
    my @org_new = @$org_ids;
    my ($login) = rset('Login')->search({ username => $username, deleted => undef })->all;
    my $login_id = $login->id;
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
}

sub hasSite($$;$)
{   my ($class, $login, @site_ids) = @_;
    return 1 if $login->{is_admin};
    foreach my $site_id (@site_ids)
    {
        return 1 if grep { $_->id == $site_id } @{$login->{sites}};
    }
}

sub hasSiteTask
{   my ($class, $login, $site_task_id) = @_;
    return 1 if $login->{is_admin};
    my $sitetask = rset('SiteTask')->find($site_task_id)
        or return;
    return 1 if grep { $_->id == $sitetask->site_id } @{$login->{sites}};
}

1;
