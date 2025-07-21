use Test;

my $debug = 0;

# use required libs
use MacOS::NativeLib "*";
use PDF::API6;
use PDF::Lite;
use PDF::Content::Color :ColorName, :color;
use PDF::Content::XObject;
use PDF::Tags;
use PDF::Content::Text::Box;

use PDF::NameTags::FreeFonts;

sub print-text {...};

my %fonts = get-loaded-fonts-hash;
my $font = %fonts<t>;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
isa-ok $page, PDF::Content::Page;

my ($x, $y) = 72, 300;

my $text = "Test text";
print-text $text, :$font, :$page;

if $debug {
    my $ofil = "test3.pdf";
    $pdf.save-as: $ofil;
    say "See output pdf file: $ofil";
}

done-testing;

sub print-text(
    $text,
    :$page!,
    # text origin
    :$x = 72, :$y = 300,
    :$font-size = 12,
    :$font!,   # the font file name
    :$angle = 0;
    :$align = "left", # right, justifi
#   :$valign = "baseline", # default is baseline which is zero reference
              # options: top, bottom, center
    ) {

    #==========================================
    $page.graphics: {
        # my $gb = "GBUMC";
        # my $tx = $cx;
        # my $ty = $cy + ($height * 0.5) - $line1Y;
        # where $x/$y is the desired reference point
        .transform: :translate($x, $y);
        if $angle {
            .transform: :rotate($angle);
        }
        #.FillColor = color White; #rgb(0, 0, 0); # color Black
        .font = $font, # %fonts<hb>, #.core-font('HelveticaBold'),
                 $font-size; # the size
        .print: $text, :$align; #, :$valign;
    }

}
