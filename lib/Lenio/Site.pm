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

package Lenio::Site;

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use Ouch;
schema->storage->debug(1);

use DateTime;
use Lenio::Schema;

sub all($)
{   my ($class, $login_id) = @_;
    $login_id or return;
    my @sites;
    my $login_rs = rset('Login')->find($login_id);
    if ($login_rs->is_admin)
    {
	my $site_rs = rset('Site')->search({}, { prefetch => 'org' });
        @sites = $site_rs->all;
    }
    else
    {
	my @login_orgs = $login_rs->login_orgs->all;
        foreach my $login_org (@login_orgs) {
            push @sites, $login_org->org->sites->all;
        }
    }
    @sites;
}

sub site($)
{   my ($class, $site_id) = @_;
    $site_id or return;
    rset('Site')->find($site_id);
}

sub fys($)
{   my ($class, $site_id) = @_;
    my $siter = rset('Site')->find($site_id) or return;

    # Calculate financial years for this organisation
    my $fyfrom = $siter->org->fyfrom;
    my $now    = DateTime->now;
    my @fys;
    if ($fyfrom->month == 1 && $fyfrom->day == 1)
    {
        # Financial year starts at beginning of year. Just show year
        for my $y ($fyfrom->year..$now->year)
        {
            push @fys, { name => $y, year => $y };
        }
    }
    else
    {
        for my $y ($fyfrom->year..$now->year-1)
        {
            push @fys, { name => "$y-".($y+1), year => $y };
        }
        # Push another year on if we're past the FY start in this year
        push @fys, { name => $now->year."-".($now->year+1), year => $now->year }
            if $now->month > $fyfrom->month && $now->day > $fyfrom->day;
    }

    \@fys;
}

sub taskRm($$)
{   my ($class, $site, $task) = @_;
    $site && $task
        or ouch 'baddata', "Site or task information missing";
    rset('SiteTask')->search({ task_id => $task, site_id => $site, ticket_id => undef })->delete
        or ouch 'dbfail', "There was a database error when removing the task";
}

sub taskAdd($$)
{   my ($class, $site, $task) = @_;
    $site && $task or return;
    my $guard = schema->txn_scope_guard;
    return if rset('SiteTask')->search({ task_id => $task, site_id => $site, ticket_id => undef })->count;
    rset('SiteTask')->create({ task_id => $task, site_id => $site })
        or ouch 'dbfail', "There was a database error when adding the task";
    $guard->commit;
}

1;
