use Test;

# use required libs

sub print-text(
    $text = "Test text",
    :$x, $y, # text origin
    :$page!,
    :$font-size = 12,
    :$font,   # the font file name
    :$angle = 0;
    :$align = "left", # right, justifi
    :$valign, # default is baseline which is zero reference
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
        .print: $text, :$align, :$valign;
    }

