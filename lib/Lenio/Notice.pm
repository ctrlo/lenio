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

package Lenio::Notice;

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use Ouch;
schema->storage->debug(1);

use Lenio::Schema;

sub new($)
{   my ($class, $notice) = @_;
    my $n = rset('Notice')->create($notice)
        or ouch 'dbfail', "There was a database error when creating the notice";
    my @toshow;
    foreach my $login (rset('Login')->search)
    {
        push @toshow, { notice_id => $n->id, login_id => $login->id };
    }
    rset('LoginNotice')->populate(\@toshow)
        or ouch 'dbfail', "There was a database error when adding the notice to users";
}

sub update($)
{   my ($class, $notice) = @_;
    my $n = rset('Notice')->find($notice->{id})
        or ouch 'badid', "The specified notice ID could not be found";
    $n->update($notice)
        or ouch 'dbfail', "There was a database error when updating the notice";
}

sub all
{   my $class = shift;
    rset('Notice')->search({}, { prefetch => 'login_notices',
                                 group_by => 'me.id',
                                 '+select' => { count => 'login_notices.login_id' },
                                 '+as'     => 'login_count',
                               });
                             
}

sub view($)
{   my ($class, $id) = @_;
    rset('Notice')->find($id);
}

sub dismiss($$)
{   my ($class, $login, $id) = @_;
    my $notice = rset('LoginNotice')->find($id) or return;
    $notice->delete if $notice->login_id == $login->{id};
}

sub delete($)
{   my ($class, $id) = @_;
    rset('LoginNotice')->search({ notice_id => $id })->delete
        or ouch 'dbfail', "There was a database error when deleting the notices from users";
    my $n = rset('Notice')->find($id)
        or ouch 'badid', "The specified notice ID could not be found";
    $n->delete
        or ouch 'dbfail', "There was a database error when deleting the notice";
}

1;
