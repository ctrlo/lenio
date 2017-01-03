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

use DateTime;

use Moo;
use MooX::Types::MooseLike::Base qw/:all/;
use MooX::Types::MooseLike::DateTime qw/DateAndTime/;

has schema => (
    is       => 'ro',
    required => 1,
);

has site_id => (
    is       => 'ro',
    isa      => Int,
    required => 1,
);

has fyfrom => (
    is  => 'lazy',
    isa => DateAndTime,
);

sub _build_fyfrom
{   my $self = shift;
    $self->schema->resultset('Site')->find($self->site_id)->org->fyfrom;
}

has year => (
    is  => 'lazy',
    isa => Int,
);

sub _build_year
{   my $self = shift;
    # First get financial year start of organisation
    my $costfrom = $self->fyfrom;
    my $now      = DateTime->now;
    $now->subtract(years => 1) # Take year off if it's in future
        if $now->month < $costfrom->month || ($now->month == $costfrom->month && $now->day < $costfrom->day);
    $now->year;
}

has costfrom => (
    is  => 'lazy',
    isa => DateAndTime,
);

sub _build_costfrom
{   my $self = shift;
    $self->fyfrom->set_year($self->year);
}

has costto => (
    is  => 'lazy',
    isa => DateAndTime,
);

sub _build_costto
{   my $self = shift;
    $self->costfrom->clone->add( years => 1 );
}

1;
