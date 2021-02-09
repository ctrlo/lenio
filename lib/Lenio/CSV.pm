use warnings;
use strict;

package Lenio::CSV;

use parent qw/Text::CSV/;

# This is rediculous. See http://georgemauer.net/2017/10/07/csv-injection.html
# Even though CSV is a text format we have to ensure code can't be executed by
# spreadsheets. Given that it is unlikely that anything donwloaded would
# contain a special character to start, we just remove them from the download.
sub combine
{   my $self = shift;
    my @cells = map { my $c = $_; $c ||= ''; $c =~ s/^[=\-\+\@]+//r } @_;
    $self->SUPER::combine(@cells);
}

1;
