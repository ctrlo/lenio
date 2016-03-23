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

package Lenio::FY;

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);
schema->storage->debug(1);

use DateTime;
use Lenio::Schema;

sub new($$;$)
{   my ($class, $site_id, $year) = @_;
    my $self   = bless {}, $class;

    # First get financial year start of organisation
    my $costfrom = rset('Site')->find($site_id)->org->fyfrom;
    # Use fy setting if selected, otherwise default to current year
    unless ($year)
    {
        my $now  = DateTime->now;
        $now->set_year($year-1) # Take year off if it's in future
            if $now->month < $costfrom->month || ($now->month == $costfrom->month && $now->day < $costfrom->day);
        $year = $now->year;
    }
    $costfrom->set_year($year);  # Set FY to the required year
    my $costto = $costfrom->clone->add( years => 1);
    $self->{costfrom} = $costfrom;
    $self->{costto}   = $costto;
    $self;
}

sub costfrom()
{   my $self = shift;
    $self->{costfrom};
}

sub costto()
{   my $self = shift;
    $self->{costto};
}

1;
