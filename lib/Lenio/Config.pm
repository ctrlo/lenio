=pod
Lenio - Web-based Facilities Management Software
Copyright (C) 2019 Ctrl O Ltd

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

package Lenio::Config;

use Moo;

with 'MooX::Singleton';

has config => (
    is      => 'rw',
    trigger => sub {
        my $self = shift;
        $self->clear_lenio;
    },
);

has lenio => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => sub { ref $_[0]->config eq 'HASH' && $_[0]->config->{lenio} },
);

1;
