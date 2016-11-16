use utf8;
package Lenio::Schema::Result::Invoice;

use strict;
use warnings;

use File::Slurp qw/read_file/;
use File::Temp qw/tempfile/;
use PDF::Create;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("InflateColumn::DateTime");

__PACKAGE__->table("invoice");

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "text", is_nullable => 1 },
  "ticket_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "disbursements",
  { data_type => "integer", is_nullable => 1 },
  "datetime",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "ticket",
  "Lenio::Schema::Result::Ticket",
  { id => "ticket_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

sub pdf
{   my ($self, %options) = @_;

    my $company = $options{company};
    my $number  = ($options{prefix} || '').$self->id;

    my $pdf = PDF::Create->new(
        Author       => $company,
        Title        => "Invoice $number",
        CreationDate => [ localtime $self->datetime->epoch ]
    );

    my $org  = $self->ticket->site_task->site->org;
    my $to   = join "\n", grep { $_ } $org->name, $org->address1, $org->address2, $org->town, $org->postcode;
    my $type = $self->ticket->site_task->task_id ? "Service Works" : "Call Out Works";

    my $root = $pdf->new_page('MediaBox' => $pdf->get_page_size('A4'));
    my $page = $root->new_page;

    # Prepare fonts
    my $font = $pdf->font('BaseFont' => 'Helvetica');
    my $fontbold = $pdf->font('BaseFont' => 'Helvetica-Bold');

    my $img = $pdf->image($options{logo});

    $page->image(
        image  => $img,
        xscale => 0.25,
        yscale => 0.25,
        xpos   => 50,
        ypos   => 792,
        xalign => 0,
        yalign => 2,
    );

    $self->_block(
        page  => $page,
        font  => $font,
        size  => 10,
        space => 2,
        text  => "$company\n$options{address}",
        x     => 400,
        y     => 792,
    );

    $page->stringc($fontbold, 18, 298, 650, "INVOICE");

    $self->_block(
        page  => $page,
        font  => $font,
        size  => 10,
        space => 2,
        text  => $to,
        x     => 70,
        y     => 630,
    );

    $page->rectangle(72, 500, 450, 40);
    $page->line(222, 540, 222, 500);
    $page->line(372, 540, 372, 500);
    $page->stroke;

    $page->stringl($font, 10, 77, 517, "Invoice Date: ".$self->datetime->strftime($options{dateformat}) );
    $page->stringl($font, 10, 227, 517, "Invoice No: $number");
    $page->stringl($font, 10, 377, 517, "Case Number: ".$org->case_number);

    $page->stringl($fontbold, 10, 70, 470, "Description:");

    $page->block_text({
        page       => $page,
        font       => $font,
        text       => $self->description,
        font_size  => 10,
        line_width => 455,
        start_y    => 0, # unused, but warnings if omitted
        end_y      => 0,
        'x'        => 70,
        'y'        => 440,
    });

    $page->stringl($font, 10, 70, 380, "These works are to be classed as ");
    $page->setrgbcolor(200, 0, 0);
    $page->stringl($font, 10, 230, 380, $type);
    $page->setrgbcolor(0, 0, 0);

    $page->rectangle(300, 230, 225, 110);
    $page->stroke;

    $self->_block(
        page  => $page,
        font  => $font,
        size  => 10,
        space => 0,
        text  => "Professional Fees:\n\nDisbursements:\n\nSub Total:\n\nVAT \@ 20%:",
        x     => 310,
        y     => 330,
    );

    my $fees          = $self->ticket->cost_actual || 0;
    my $disbursements = $self->disbursements || 0;
    my $subtotal      = $fees + $disbursements;
    my $vat           = $subtotal * 0.2;
    my $total         = $subtotal + $vat;
    $self->_block(
        page  => $page,
        font  => $font,
        size  => 10,
        space => 0,
        text  => sprintf("\xA3%.2f\n\n\xA3%.2f\n\n\xA3%.2f\n\n\xA3%.2f\n", $fees, $disbursements, $subtotal, $vat),
        x     => 450,
        y     => 330,
    );

    $page->stringl($fontbold, 10, 310, 240, "TOTAL:");
    $page->stringl($fontbold, 10, 450, 240, sprintf("\xA3%.2f", $total));

    $page->rectangle(345, 108, 180, 82);
    $page->stroke;
    $page->setrgbcolor(200, 0, 0);

    $self->_block(
        page  => $page,
        font  => $font,
        size  => 8,
        space => 1,
        text  => $options{payment},
        x     => 350,
        y     => 185,
    );

    $page->setrgbcolor(0, 0, 0);
    $page->block_text({
        page       => $page,
        font       => $font,
        text       => $options{footer},
        font_size  => 8,
        line_width => 455,
        start_y    => 0, # unused, but warnings if omitted
        end_y      => 0,
        'x'        => 70,
        'y'        => 80,
    });

    $page->stringl($fontbold, 8, 70, 30, $options{footer_left});
    $page->stringr($fontbold, 8, 515, 30, $options{footer_right});

    # Close the file and returne the PDF content
    return $pdf->close;
}

sub _block
{   my ($self, %options) = @_;

    my $size  = $options{size} || 10;
    my $space = $options{space} || 0;
    my @lines = split "\n", $options{text};
    my $x     = $options{x};
    my $y     = $options{y} - $size;
    foreach my $line (@lines)
    {
        $options{page}->stringl($options{font}, $size, $x, $y, $line);
        $y = $y - $size - $space;
    }
}

1;
