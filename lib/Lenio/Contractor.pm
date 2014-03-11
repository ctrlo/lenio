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

package Lenio::Contractor;

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
use Ouch;
schema->storage->debug(1);

use Lenio::Schema;

sub new($)
{   my ($class, $contractor) = @_;
    $contractor or ouch 'noname', "No contractor name was supplied";
    rset('Contractor')->create($contractor) or return;
}

sub update($)
{   my ($class, $contractor) = @_;
    my $c = rset('Contractor')->find($contractor->{id})
        or ouch 'badid', "Unable to find specified contractor";
    $c->update($contractor)
        or ouch 'dbfail', "There was a database error when updating the contractor";
    $c;
}

sub all
{   my $class = shift;
    rset('Contractor')->search;
}

sub view($)
{   my ($class, $id) = @_;
    rset('Contractor')->find($id);
}

sub delete($)
{   my ($class, $id) = @_;
    my $c = rset('Contractor')->find($id)
        or ouch 'badid', "Unable to find specified contractor";
    $c->delete;
}

1;
