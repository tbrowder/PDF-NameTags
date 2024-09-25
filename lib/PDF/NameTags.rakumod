unit module PDF::NameTags;

use PDF::API6;
use PDF::Lite;
use PDF::Content::Color :ColorName, :color;
use PDF::Content::XObject;
use PDF::Tags;
use PDF::Content::Text::Box;

use Compress::PDF;

use PDF::NameTags::FreeFonts;

# My initial guess at the rose window colors (rgb triplets)
# based on my comparing the image on the church website
# to the W3C rgb color picker website.
#
# I may update the values as needed after seeing printed results.
constant %colors = %(
    1 => [255, 204, 102],
    2 => [  0,   0,   0],
    3 => [153, 204, 255],
    4 => [  0, 102, 255],
    5 => [ 51, 153, 102],
    6 => [204,  51,   0],
);

# Letter paper
#==============
# letter, portrait
my $pw = 8.5*72;
my $ph = 11*72;
#==============

# Allow at least a 1/2-inch margin at the top
# for page number and first and last names on the
# sheet. Allow 1/4-inch margins elsewhere.
# Total margins vertically:   0.75"
# Total margins horizontally: 0.5"

# To allow reverse-printing, each list of names
# on a front row will be reversed on the reverse
# side.

# current badge dimensions (width, height)
my @badge = 3.84, 2.26; # Amazon, 0.1" less than listed dimensions to allow in-pocket
# still too wide, trim another 1/8" of width
@badge[0] -= 0.125;

my $bwi = @badge.head; # badge width
my $bhi = @badge.tail; # badge height
# all dimens in PS points:
my $bw = $bwi * 72; # badge width
my $bh = $bhi * 72; # badge height
my $hm = 0.5*72;  # total horizontal margins
my $vm = 0.75*72; # total vertical margins

# Given 2 columns x 4 rows per page and the
# margins and gutters, we need to define
# midpoints of each badge.
# Per row, margins are 0.5" total. Midpoint
# in width is 4.25". Give 1/4" between badges. Then:
my $mx = 4.25 * 72;
my $dx = (0.125 + (0.5 * $bwi)) * 72;
my $h1 = $mx - $dx;
my $h2 = $mx + $dx;

# Allow 1/4" between rows. Top of first
# row 0.5" with 1/14" between rows.
my $v1 = (11 - 0.5 - (0.5 * $bhi)) * 72;
my $dy = ($bhi + 0.25) * 72;
my $v2 = $v1 - $dy;
my $v3 = $v2 - $dy;
my $v4 = $v3 - $dy;

# With remaining
# space of 7",
our %dims = %(
  bwi => $bwi,
  bhi => $bhi,
  bw  => $bwi * 72, # badge width
  bh  => $bhi * 72, # badge height
  hm  => 0.5*72,    # horizontal margins
  vm  => 0.75*72,   # vertical margins
  pw  => $pw,
  ph  => $ph,
);

my %fonts = get-loaded-fonts-hash;

#==== subroutines
sub get-dims-hash(--> Hash) is export {
    # name tag dimensions
    %dims;
}

sub make-badge-page(
    @p,       # list of 8 or less names for a page
    :$side!  where $side ~~ /front | back/,
    :$page!,
    :$page-num!,
    :$project-dir!,
    :$method!,
    :$printer!,
    :$debug,
) is export {
    my @r = @p;
    my (@c, $n); #    cy     cx      cx
    my ($vmid, $hmid1, $hmid2);

    # For front wide, work row cells left to right.
    #   cell 1 | cell 2
    # For back side, work row cell right to left.
    #   cell 2 | cell 1

    say "Page $page-num (a $side side)" if $debug;
    my $rnum = 0;
    while @r.elems {
        my $ncells = 1;
        my $nam1 = @r.shift;
        my $nam2 = @r.elems ?? @r.shift !! 0;
        ++$ncells if $nam2;

        ++$rnum;
        # get the cell midpoints
        if $rnum == 1 { $vmid = $v1 }
        if $rnum == 2 { $vmid = $v2 }
        if $rnum == 3 { $vmid = $v3 }
        if $rnum == 4 { $vmid = $v4 }

        $hmid1 = $h1; # for front side
        $hmid2 = $h2; # for front side
        my $s = $ncells > 1 ?? 's' !! '';
        say "  row $rnum with $ncells badge$s" if $debug;

        my $cy = $vmid;
        # make the labels at their correct locations
        if $side eq "front" {
            # cell 1 on left
            # cell 2 on right
        }
        else {
            # cell 1 on right
            # cell 2 on left
            $hmid1 = $h2; # for back side
            $hmid2 = $h1; # for back side
        }

        if $rnum == 1 {
            # place page data and printer info
            # assume the midpoint of the center vertical gutter
            #   is $hmid1 + (0.5 * ($hmid2 - $hmid1))
            my $cx-gutter = $hmid1 + 0.5 * ($hmid2 - $hmid1);
            my $cy-gutter = 0.5 * $ph;

            write-page-data :$printer, :cx($cx-gutter), :cy($cy-gutter), :$side,
                                       :$page, :$debug;
        }

        make-label($nam1, :width($bw), :height($bh), :cx($hmid1), :$cy,
            :$page, :$project-dir, :$method, :$debug);
        make-label($nam2, :width($bw), :height($bh), :cx($hmid2), :$cy,
            :$page, :$project-dir, :$method, :$debug) if $nam2;
    }

} # sub make-badge-page(

our &make-name-tag = &make-label;
sub make-label(
    $text,        # string: "last first middle"
    :$width,      # points
    :$height,     # points
    :$cx!, :$cy!, # center of label in points
    :$page!,
    :$project-dir!,
    :$method!,
    :$debug,
    # default color for top portion is blue

) is export {
    if $debug {
        say "Making a name tag...";
    }

    # translate to the center
    #   blue the top section
    #   GBUMC in white in blue section
    #   first (and any middle) name in middle section
    #   last name in lower section
    #
    # outline the labels with a 0 width interior line

    # Note we bound the top area by width and height and put any
    # graphics inside that area.

    # label constants for tweaking (in points):
    # for now the cross will be a circle enclosing a symmetrical +
    #   colored white on the blue background
    my $cross-diam;
    my $cross-thick;
    my $crossX;
    my $crossY;

    # valign value from top of label
    my $line1Y     = (0.15) * $height;                # 0.3 size of label
    my $line1size  = 25;
    my $line2Y     = (0.3 + 0.1725) * $height;        # 0.35 size of label
    my $line2size  = 40;
    my $line3Y     = (0.3 + 0.35 + 0.1725) * $height; # 0.35 size of label
    my $line3size  = 40;

    # cross/rose window params
    my $diam    = 0.35*72;
    my $thick   = 2;
    my $cwidth  = 1*72;
    my $cheight = 0.3 * 72;
    my $ccxL    = $cx - ($width * 0.5);
    my $ccxR    = $cx + ($width * 0.5);
    my $cross-offset = 30;
    $ccxL  += $cross-offset; # center of cross 30 points right of left side
    $ccxR  -= $cross-offset; # center of cross 30 points left of right side
    my $ccy = $cy + ($height * 0.5) - $line1Y;

    #==========================================
    # the rectangular outline
    $page.graphics: {
        # translate to top-left corner
        my $ulx = $cx - 0.5 * $width;
        my $uly = $cy + 0.5 * $height;

        .transform: :translate($ulx, $uly);
        .StrokeColor = color Black;
        #.FillColor = rgb(0, 0, 0); # color Black
        .LineWidth = 0;
        .Rectangle(0, -$height, $width, $height);
        .Stroke; #paint: :fill, :stroke;
    }

    #==========================================
    # the upper blue part
    my $blue = [0, 102, 255]; # from color picker
    $page.graphics: {
        # translate to top-left corner
        my $ulx = $cx - 0.5 * $width;
        my $uly = $cy + 0.5 * $height;
        .transform: :translate($ulx, $uly);
        .FillColor = color $blue; #[0, 0, 0.3]; #Navy; #rgb(0, 0, 0.5);
        .LineWidth = 0;
        # the height is part of label $height
        my $bh = $height * 0.3;
        .Rectangle(0, -$bh, $width, $bh);
        .paint: :fill, :stroke;
    }

    #==========================================
    # the "master" subs that create the entire cross symbol, including
    # the rose window background

    make-cross(:$diam, :$thick, :width($cwidth),
               :height($cheight), :cx($ccxL), :cy($ccy), :$page,
               :$method, :$project-dir, :$debug);
    make-cross(:$diam, :$thick, :width($cwidth),
               :height($cheight), :cx($ccxR), :cy($ccy), :$page,
               :$method, :$project-dir, :$debug);

    #==========================================
    # gbumc text in the blue part
    $page.graphics: {
        my $gb = "GBUMC";
        my $tx = $cx;
        my $ty = $cy + ($height * 0.5) - $line1Y;
        .transform: :translate($tx, $ty); # where $x/$y is the desired reference point
        .FillColor = color White; #rgb(0, 0, 0); # color Black
        .font = %fonts<hb>, #.core-font('HelveticaBold'),
                 $line1size; # the size
        .print: $gb, :align<center>, :valign<center>;
    }

    #==========================================
    # the congregant names on two lines
    my @w = $text.words;
    my $last = @w.shift;
    my $first = @w.shift;
    my $middle = @w.elems ?? @w.shift !! 0;
    $first = "$first $middle" if $middle;
    say "first: $first" if $debug;
    say "last: $last" if $debug;

    # line 2 (first name), grays:
    my $tcolor = 0.2; #[72, 72, 72]; # 0.7;

    $page.graphics: {
        # translate to top-middle
        my $uly = $cy + 0.5 * $bh;
        my $tx = $cx;
        my $ty = $cy + ($height * 0.5) - $line2Y;

        # TWEAK down
        $ty -= 5;
        .transform: :translate($tx, $ty); # where $x/$y is the desired reference point
        #.text-transform: :translate($tx, $ty);
        .FillColor = color $tcolor; #Black; #rgb(0, 0, 0); # color Black
        .font = %fonts<hb>, #.core-font('HelveticaBold'),
                 $line2size; # the size
        .print: $first, :align<center>, :valign<center>;
    }

    # line 3 (last name)
    $page.graphics: {
        # translate to top-middle
        my $uly = $cy + 0.5 * $bh;
        my $tx = $cx;
        my $ty = $cy + ($height * 0.5) - $line3Y;

        # TWEAK up
        $ty += 5;
        .transform: :translate($tx, $ty); # where $x/$y is the desired reference point
        #.text-transform: :translate($tx, $ty);
        .FillColor = color $tcolor; #Black; #rgb(0, 0, 0); # color Black
        .font = %fonts<hb>, #.core-font('HelveticaBold'),
                 $line3size; # the size
        .print: $last, :align<center>, :valign<center>;
    }

    #==========================================
    # label is done

} # sub make-label(

our &draw-disk = &draw-ring;
sub draw-ring(
    $x, $y,  # center point
    $r,      # radius
    :$thick!, # outer radius - inner radius
    :$page!,
    :$fill,
    :$stroke,
    :$color,
    :$linewidth = 0,
    :$debug,
    ) is export {

# TODO clip needed

    # need inside clip of a disk
    # first draw the outer circle path clockwise
    # then draw the inner circle path counterclockwise
    # then clip


    =begin comment
    $page.graphics: {
        .SetLineWidth: $linewidth; #, :$color;
	.StrokeColor = color $color;
	.FillColor   = color $color;
        # from stack overflow: copyright 2022 by Spencer Mortenson
        .transform: :translate($x, $y);
        constant c = 0.551915024495;

        # outer cicle
        .MoveTo: 0*$r, 1*$r; # top of the circle
        # use four curves, counterclockwise (positive direction)
        .CurveTo: -1*$r,  c*$r, -c*$r,  1*$r,  0*$r,  1*$r;
        .CurveTo: -c*$r, -1*$r, -1*$r, -c*$r, -1*$r,  0*$r;
        .CurveTo:  1*$r, -c*$r,  c*$r, -1*$r,  0*$r, -1*$r;
        .CurveTo:  c*$r,  1*$r,  1*$r,  c*$r,  1*$r,  0*$r;
        #.ClosePath;

        # inner circle
        my $R = $r - $thick;
        .MoveTo: 0*$R, 1*$R; # top of the circle
        # use four curves, clockwise (negative direction)
	.StrokeColor = color [0]; # black$color;
	.FillColor   = color [0]; # black$color;
        .CurveTo:  c*$R,  1*$R,  1*$R,  c*$R,  1*$R,  0*$R;
        .CurveTo:  1*$R, -c*$R,  c*$R, -1*$R,  0*$R, -1*$R;
        .CurveTo: -c*$R, -1*$R, -1*$R, -c*$R, -1*$R,  0*$R;
        .CurveTo: -1*$R,  c*$R, -c*$R,  1*$R,  0*$R,  1*$R;
        .ClosePath;
        .Clip;
        .EndPath;

        if $fill and $stroke {
            .FillStroke;
        }
        elsif $fill {
            .Fill;
        }
        elsif $stroke {
            .Stroke;
        }
    }
    =end comment
}


=begin comment
sub draw-cross(
    :$height!,
    :$width = $height, # default is same as height
    :$hcross = 0.5, # ratio of height and distance of crossbar from the top
    :$thick!,
    :$page!,
    ) is export {
}
=end comment

sub make-cross(
    # overall dia
    :$diam!,
    :$thick!,
    :$width!,     # points
    :$height!,    # points
    :$cx!, :$cy!, # points
    :$page!,
    :$project-dir!,
    :$method!,
    :$debug,
    # default color is white
) is export {

    if $debug {
        say "  Making the cross parts...";
    }

    #=begin comment
    # TODO make test, file issue
    # load the png image
    my $image-path = "$project-dir/GBUMC-logo.png";
    #=end comment

    # initial model will be a hollow circle with symmetrical spokes in
    # shape of a cross, with a rose background color to simulate
    # GBUMC's rose window
    my $radius = $diam*0.5; # * 200;

    # create a white, filled, thinly stroked circle of the total
    # diameter
    # draw a white circle with a black center hole
    if $debug {
        say "    Drawing a filled, white circle...";
    }

    # create a clipped, inner circular path with radius inside
    # by the thickness
    # create the stained-glass portion
    # as a rectangular pattern set
    # to the height and width of the circle
    $page.gfx.Save;
    draw-circle-clip $cx, $cy, $radius, :clip, :$page;
    draw-circle-clip $cx, $cy, $radius, :fill, :fill-color(color White),
                     :stroke, :stroke-color(color White), :$page;

    place-image $cx, $cy, :$image-path, :$method, :$page;

    =begin comment
    # the colored pattern
    draw-circle-clip $cx, $cy, $radius-2, :clip, :$page;
    draw-color-wheel :$cx, :$cy, :radius($radius+20), :$page;
    draw-cross-parts :x($cx), :y($cy), :$width, :$height,
                     :$page;
    =end comment

    $page.gfx.Restore;

    =begin comment
    # 4 pieces
    my ($lrx, $lry, $llx, $lly, $urx, $ury, $ulx, $uly);
    my ($width-pts);
    my ($stroke-color, $fill-color) = 1, 0;
    # upper left rectangle
    draw-ul-rect :$llx, :$lly, :$width, :$height, :$width-pts,
                 :$stroke-color, :$fill-color, :$page;
    # upper right rectangle
    draw-ur-rect :$llx, :$lly, :$width, :$height, :$width-pts,
                 :$stroke-color, :$fill-color, :$page;
    # lower left rectangle
    draw-ll-rect :$llx, :$lly, :$width, :$height, :$width-pts,
                 :$stroke-color, :$fill-color, :$page;
    # lower right rectangle
    draw-lr-rect :$llx, :$lly, :$width, :$height, :$width-pts,
                 :$stroke-color, :$fill-color, :$page;
    =end comment


    # create the white spokes

    =begin comment
    # inner filled with rose
    my $rose = [255, 153, 255]; # from color picker
    draw-circle-clip $cx, $cy, $radius-$thick, :color($rose), :$page;

    # outer filled with white with a cross inside as part of it
    # is placed over the "rose" part
    draw-circle-clip $cx, $cy, $radius, :color(1), :$page;
    =end comment

    =begin comment
    $page.graphics: {
        .transform: :translate($cx, $cy);
        #.StrokeColor = color Black;
        .FillColor = Blue; #rgb(0, 0, 0); #color Black
        #.LineWidth = 2;
        .Rectangle(0, -$height, $width, $height);
        .paint: :fill, :stroke;
    }
    =end comment

} # sub make-cross(

sub draw-star(
    $x, $y, $r,
    :$stroke,
    :$fill,
    :$page,
    :$debug,
) is export {
    # draw a local 5-pointed star
    # first point is at top center

    my %point;
    # create the proper values for the five points
    my $delta-degrees = 360.0 / 5;
    for 0..^5 -> $i {
        my $degrees = $i * $delta-degrees;
        my $radians = deg2rad($degrees);


        if $i == 0 {
            %point{$i}<x> = 0;  #$r * sin($radians);
            %point{$i}<y> = $r; #  * cos($radians);
            next;
        }

        %point{$i}<x> = $r * sin($radians);
        %point{$i}<y> = $r * cos($radians);
    }
    if $debug {
        say "DEBUG: Star points:";
        for 0..4 {
            my $x = %point{$_}<x>;
            my $y = %point{$_}<y>;
            say "  point $_: x ($x), y ($y)";
        }
    }

    $page.graphics: {
    .transform: :translate($x, $y);
    .StrokeColor = color Black;
    .FillColor   = color White;
    .MoveTo: %point<0><x>, %point<0><y>; # point 0 (top of the star)
    .LineTo: %point<2><x>, %point<2><y>; # point 2
    .LineTo: %point<4><x>, %point<4><y>; # point 4
    .LineTo: %point<1><x>, %point<1><y>; # point 1
    .LineTo: %point<3><x>, %point<3><y>; # point 3
    .LineTo: %point<0><x>, %point<0><y>; # point 0
    .CloseStroke;
    } # end of $page-graphics

} # sub draw-star(

sub draw-circle-clip(
    $x, $y, $r,
    :$page!,
    :$stroke-color = (color Black),
    :$fill-color   = (color White),
    :$linewidth = 0,
    :$fill is copy,
    :$stroke is copy,
    :$clip is copy,
    :$debug,
) is export {
    $fill   = 0 if not $fill.defined;
    $stroke = 0 if not $stroke.defined;
    $clip   = 0 if not $clip.defined;
    # what if none are defined?
    if $clip {
        # illegal to do anything else with current state of PDF::Content
        ($fill, $stroke) = 0, 0;
    }
    else {
        # make stroke the default
        $stroke = 1 if not ($fill or $stroke);
    }

    if $debug {
        say "   Drawing a circle...";
        if $fill {
            say "     Filling with color $fill-color...";
        }
        if $stroke {
            say "     Stroking with color $stroke-color...";
        }
        if $clip {
            say "     Clipping the circle";
        }
        else {
            say "     NOT clipping the circle";
        }
    }

    #my $g = $gfx ?? $gfx !! $page.gfx;
    my $g = $page.gfx;
    $g.Save if not $clip;

    if not $clip {
        $g.SetLineWidth: $linewidth; #, :$color;
        $g.StrokeColor = $stroke-color;
        $g.FillColor   = $fill-color; # $fill-color;
        #$g.transform: :translate($x, $y);
        #$g.MoveTo: 0*$r, 1*$r; # top of the circle
    }
    else {
    }
    constant k = 0.551_785; #_777_790_14;

    $g.MoveTo: $x+(0*$r), $y+(1*$r); # top of the circle
    # use four curves, counter-clockwise
    # upper-left arc
    #          -X-    -Y-
    $g.CurveTo: $x+(-k*$r),  $y+(1*$r),  # 1
                $x+(-1*$r),  $y+(k*$r),  # 2
                $x+(-1*$r),  $y+(0*$r);  # 3

    # lower-left arc
    $g.CurveTo: $x+(-1*$r), $y+(-k*$r),  # 4
                $x+(-k*$r), $y+(-1*$r),  # 5
                $x+( 0*$r), $y+(-1*$r);  # 6

    # lower-right arc
    $g.CurveTo: $x+(k*$r),  $y+(-1*$r),  # 7
                $x+(1*$r),  $y+(-k*$r),  # 8
                $x+(1*$r),  $y+(0*$r);   # 9

    # upper-right arc
    $g.CurveTo: $x+(1*$r),  $y+(k*$r),   # 10
                $x+(k*$r),  $y+(1*$r),   # 11
                $x+(0*$r),  $y+(1*$r);   # 12 (also the starting point)
    $g.ClosePath;

    if not $clip {
        if $fill and $stroke {
            $g.FillStroke;
        }
        elsif $fill {
            $g.Fill;
        }
        elsif $stroke {
            $g.Stroke;
        }
        else {
            die "FATAL: Unknown drawing status";
        }

        $g.Restore;
    }
    else {
        $g.Clip;
        $g.EndPath;
    }

} # sub draw-circle-clip(

sub write-cell-line(
    # text only
    :$text = "<text>",
    :$page!,
    :$x0!, :$y0!, # the desired text origin
    :$width!, :$height!,
    :$Halign = "center",
    :$Valign = "center",
) is export {
    =begin comment
    # simple version
    $page.text: {
        # $x0, $y0 MUST be the desired origin for the text
        .text-transform: :translate($x0+0.5*$width, $y0-0.5*$height);
        .font = .core-font('Helvetica'), 15;
        .print: $text, :align<center>, :valign<center>;
    }
    =end comment
    $page.text: {
        # $x0, $y0 MUST be the desired origin for the text
        .text-transform: :translate($x0+0.5*$width, $y0-0.5*$height);
        .font = .core-font('Helvetica'), 15;
        with $Halign {
            when /left/   { :align<left> }
            when /center/ { :align<center> }
            when /right/  { :align<right> }
            default {
                :align<left>;
            }
        }
        with $Valign {
            when /top/    { :valign<top> }
            when /center/ { :valign<center> }
            when /bottom/ { :valign<bottom> }
            default {
                :valign<center>;
            }
        }
        .print: $text, :align<center>, :valign<center>;
    }
} # sub write-cell-line(

sub draw-cell(
    # graphics only
    :$text,
    :$page!,
    :$x0!, :$y0!, # upper left corner
    :$width!, :$height!,
    ) is export {

    # Note we bound the area by width and height and put any
    # graphics inside that area.
    $page.graphics: {
        .transform: :translate($x0, $y0);
        # color the entire form
        .StrokeColor = color Black;
        #.FillColor = rgb(0, 0, 0); #color Black
        .LineWidth = 2;
        .Rectangle(0, -$height, $width, $height);
        .Stroke; #paint: :fill, :stroke;
    }
} # sub draw-cell(

# algorithms
sub show-nums($landscape = 0) is export {
    my ($nc, $nr, $hgutter, $vgutter);
    my $W = $pw;
    my $H = $ph;
    if $landscape {
        $W = $ph;
        $H = $pw;
        # landscape
        #   num cols of cards
        $nc = ($W - $hm) div $bw;
        #   num rows of cards
        $nr = ($H - $vm) div $bh;

        $hgutter = ($W - ($nc * $bw)) / ($nc - 1);
        $vgutter = ($H - ($nr * $bh)) / ($nr - 1);
    }
    else {
        # portrait
        #   num cols of cards
        $nc = ($W - $hm) div $bw;
        #   num rows of cards
        $nr = ($H - $vm) div $bh;

        $hgutter = ($W - ($nc * $bw)) / ($nc - 1);
        $vgutter = ($H - ($nr * $bh)) / ($nr - 1);
    }
    # convert gutter space back to inches
    $hgutter /= 72.0;
    $vgutter /= 72.0;
    $nc, $nr, $hgutter, $vgutter
} # sub show-nums($landscape = 0) is export {

=begin comment
# upper-left quadrant
sub draw-ul-rect(
    :$llx!,       # in centimeters
    :$lly!,       # in centimeters
    :$width!,     # in centimeters
    :$height!,    # in centimeters
    :$width-pts!, # in desired PS points, scale cm dimens accordingly
    # probably don't need these
    :$stroke-color = (color Black),
    :$fill-color   = (color White),
    :$page!,
    ) is export {
    # on the sketch are 10 rectangle numbers, use them here
    # also rgb colors are on the sketch for some blocks
    # the sketch is accompanied by a graph drawing showing blown-up
    #   dimensions in centimeters which must be scaled down by the
    #   appropriate factor
    # pane 1 rgb: 204, 51, 0
    draw-rectangle :llx(0), :lly(0), :width(20), :height(20),
                   :$stroke-color, :$fill-color, :$page;
    # pane 2 rgb:
    # pane 3 rgb: 153, 204, 255
    # pane 4 rgb: 0, 0, 0
    # pane 5 rgb: 255, 204, 102
    # pane 6 rgb:
    # pane 7 rgb:
    # pane 8 rgb:
    # pane 9 rgb: 0, 102, 255
    # pane 10 rgb: 51, 153, 102
}

# upper-right quadrant
sub draw-ur-rect(
    :$llx!,  # in centimeters
    :$lly!,  # in centimeters
    :$xlen!, # in desired PS points, scale accordingly
    :$stroke-color = [0], # black
    :$fill-color   = [1], # white
    :$page!,
    ) is export {
}

# lower-left quadrant
sub draw-ll-rect(
    :$llx!,  # in centimeters
    :$lly!,  # in centimeters
    :$xlen!, # in desired PS points, scale accordingly
    :$stroke-color = [0], # black
    :$fill-color   = [1], # white
    :$page!,
    ) is export {
}

# lower-right quadrant
sub draw-lr-rect(
    :$llx!,  # in centimeters
    :$lly!,  # in centimeters
    :$xlen!, # in desired PS points, scale accordingly
    :$stroke-color = [0], # black
    :$fill-color   = [1], # white
    :$page!,
    ) is export {
}
=end comment

our &draw-box-clip = &draw-rectangle-clip;
sub draw-rectangle-clip(
    :$llx!,
    :$lly!,
    :$width!,
    :$height!,
    :$stroke-color = (color Black),
    :$fill-color   = (color White),
    :$fill is copy,
    :$stroke is copy,
    :$clip is copy,
    :$page!,
    ) is export {

    $stroke = 0 if not $stroke.defined;
    $fill   = 0 if not $fill.defined;
    $clip   = 0 if not $clip.defined;
    # what if none are defined?
    if $clip {
        # illegal to do anything else with current state of PDF::Content
        ($fill, $stroke) = 0, 0;
    }
    else {
        # make stroke the default
        $stroke = 1 if not ($fill or $stroke);
    }

    #$page.graphics: {
    my $g = $page.gfx;
    $g.Save;
    # NO translation
    $g.FillColor = color $fill-color;
    $g.StrokeColor = color $stroke-color;
    $g.LineWidth = 0;
    $g.MoveTo: $llx, $lly;
    $g.LineTo: $llx+$width, $lly;
    $g.LineTo: $llx+$width, $lly+$height;
    $g.LineTo: $llx       , $lly+$height;
    $g.ClosePath;

    if $fill and $stroke {
        $g.FillStroke;
    }
    elsif $fill {
        $g.Fill;
    }
    elsif $stroke {
        $g.Stroke;
    }
    $g.Restore;
    # }

} # sub draw-rectangle(

class GraphPaper {
    #=========================
    #== defaults for Letter paper
    my $page-margins   = 0.4 * 72;
    # use letter paper
    my $cell-size      = 0.1; # desired minimum cell size (inches)
    $cell-size     *= 72;  # now in points
    my $cells-per-grid = 10;  # heavier line every X cells
    my $cell-linewidth     =  0; # very fine line
    my $mid-grid-linewidth =  0.75; # heavier line width (every 5 cells)
    my $grid-linewidth     =  1.40; # heavier line width (every 10 cells)
    #=========================
}

sub make-graph-paper($ofil) is export {
    #=========================
    #== defaults for Letter paper
    my $page-margins   = 0.4 * 72;
    # use letter paper
    my $cell-size      = 0.1; # desired minimum cell size (inches)
    $cell-size     *= 72;  # now in points
    my $cells-per-grid = 10;  # heavier line every X cells
    my $cell-linewidth     =  0; # very fine line
    my $mid-grid-linewidth =  0.75; # heavier line width (every 5 cells)
    my $grid-linewidth     =  1.40; # heavier line width (every 10 cells)

    #=========================
    # Determine maximum horizontal grid squares for Letter paper,
    # portrait orientation, and 0.4-inch horizontal margins.
    my $page-width  = 8.5 * 72;
    my $page-height = 11  * 72;
    my $max-graph-size = $page-width - $page-margins * 2;
    my $max-ncells = $max-graph-size div $cell-size;

    my $ngrids = $max-ncells div $cells-per-grid;
    my $graph-size = $ngrids * $cells-per-grid * $cell-size;
    my $ncells = $ngrids * $cells-per-grid;
    say qq:to/HERE/;
    Given cells of size $cell-size x $cell-size points, with margins,
      with grids of $cells-per-grid cells per grid = $ngrids.
    HERE

    my $pdf  = PDF::Lite.new;
    $pdf.media-box = 0, 0, $page-width, $page-height;
    my $page = $pdf.add-page;

    # Translate to the lower-left corner of the grid area
    my $llx = 0 + 0.5 * $page-width - 0.5 * $graph-size;
    my $lly = $page-height - 72 - $graph-size;
    $page.graphics: {
        .transform: :translate($llx, $lly);

        # draw horizontal lines, $y is varying 0 to $twidth
        #   bottom to top
        for 0..$ncells -> $i {
            my $y = $i * $cell-size;
            if not $i mod 10 {
                .LineWidth = $grid-linewidth;
            }
            elsif not $i mod 5 {
                .LineWidth = $mid-grid-linewidth;
            }
            else {
                .LineWidth = $cell-linewidth;
            }
            .MoveTo: 0,           $y;
            .LineTo: $graph-size, $y;
            .Stroke;
        }
        # draw vertical lines, $x is varying 0 to $twidth
        #   left to right
        for 0..$ncells -> $i {
            my $x = $i * $cell-size;
            if not $i mod 10 {
                .LineWidth = $grid-linewidth;
            }
            elsif not $i mod 5 {
                .LineWidth = $mid-grid-linewidth;
            }
            else {
                .LineWidth = $cell-linewidth;
            }
            .MoveTo: $x, 0;
            .LineTo: $x, $graph-size;
            .Stroke;
        }
    }

    $pdf.save-as: $ofil;
    say "See output file: '$ofil'";
} # sub make-graph-paper($ofil) is export {

sub deg2rad($degrees) {
    $degrees * pi / 180
}

sub rad2deg($radians) {
    $radians * 180 / pi
}

sub draw-color-wheel(
    :$cx!, :$cy!,
    :$radius!,
    :$page!,
    :$debug,
    ) is export {
    # a hex wheel of different-colored triangles centered
    # on the circle defined with the inputs

    note "DEBUG: in sub draw-color-wheel" if $debug;
    my $g = $page.gfx;
    #$page.gfx: {
    $g.Save;
    my $cnum = 0; # color number in %colors
    #my $stroke-color = color Black;
    my $stroke-color = color White;
    for 0..^6 {
        ++$cnum; # color number in %colors
        my $angle = $_ * 60;
        my $fill-color = color %colors{$cnum};
        note "DEBUG: fill color = '$fill-color'" if $debug;
        draw-hex-wedge :$cx, :$cy, :height($radius), :$angle, :stroke,
                       :fill, :$fill-color, :$stroke-color, :$page;
    }
    $g.Restore;

} # sub draw-color-wheel(

sub draw-hex-wedge(
    :$cx!, :$cy!,
    :$height!, # apex at cx, ch, height is perpendicular at the base
    :$angle!,  # degrees ccw from 3 o'clock
    :$fill is copy,
    :$stroke is copy,
    :$fill-color, #   = (color Red),
    :$stroke-color, # = (color Black),
    :$page!,
    :$debug,
    ) is export {

    $fill   = 0 if not $fill.defined;
    $stroke = 0 if not $stroke.defined;
    unless ($fill or $stroke) {
        $stroke = 1;
    }

    #
    #          0
    #         /|\ equilateral triangle
    #        / | \ c
    #       /  |h \ 60 deg
    #    1 /---+---\ 2      given: h, angles 1 and 2 60 degrees each
    #       -a   +a
    #                    h/a = tan 60 deg
    #                   |a|  = h / tan 60
    #
    my $a = $height / tan(deg2rad(60));
    # point 0 is $cx,$cy --> 0, 0
    # rotate as desired by $angle
    # draw the triangle

note "DEBUG: stroke color: $stroke-color" if $debug;
note "DEBUG: fill   color: $fill-color" if $debug;

    my $g = $page.gfx;
    $g.Save;
    $g.transform :translate($cx,$cy); # now apex is at 0, 0
    $g.transform :rotate(deg2rad($angle)); # h is positive x: 0 to h, y = 0
    $g.LineWidth = 0;
    $g.FillColor   = color $fill-color;
    $g.StrokeColor = color $stroke-color;
    $g.MoveTo: 0, 0;
    $g.LineTo: $height, -$a;
    $g.LineTo: $height, +$a;
    $g.LineTo:   0,   0;
    $g.ClosePath;
    if $fill and $stroke {
        $g.FillStroke;
    }
    elsif $fill {
        $g.Fill;
    }
    elsif $stroke {
        $g.Stroke;
    }
    $g.Restore;

} # sub draw-hex-wedge(

sub simple-clip1(
    :$x is copy,
    :$y is copy,
    :$width  is copy,
    :$height is copy,
    :$stroke-color = (color Black),
    :$fill-color   = (color White),
    :$page!,
    :$debug,
    ) is export {

    # draw a local circle for clipping
    if not ($x.defined and $y.defined) {
        $x = 0.5 * $page.media-box[2];
        $y = 0.5 * $page.media-box[3];
    }
    if not ($width.defined and $height.defined) {
        $width  = 72;
        $height = 72;
    }
    my $radius = 0.5 * $width;
    my $R = $radius;

    my $g = $page.gfx;
    $g.Save;

    $g.transform: :translate($x, $y);

    $g.StrokeColor = color Black;
    $g.FillColor   = color White;

    #=== Begin: define the clipping path ===
    #==    without calling subs
    # define the path per the localized CTM
    $g.Rectangle: -1*72, -1*72, 2*72, 2*72;
    # clip the path
    $g.Clip;
    # end the clipping path definition
    $g.EndPath;
    #=== End: define the clipping path ===

    # show the clipping path
    $g.FillColor = color Red; # White;
    $g.Rectangle: -1*72, -1*72, 2*72, 2*72;
    $g.FillStroke;

    # an offset blue rectangle
    # offset to the lower left so
    # its top-right corner is stiil
    # visible
    $g.FillColor = color Blue; # White;
    $g.Rectangle: -1.5*72, -1.5*72, 2*72, 2*72;
    $g.FillStroke;

    =begin comment
    # use four Bezier curves, counter-clockwise
    # from stack overflow: copyright 2022 by Spencer Mortenson
    #   but reversed direction
    constant c = 0.551915024495;
    $g.MoveTo:   0*$R,  1*$R; # top of the circle
    $g.CurveTo: -1*$R,  c*$R, -c*$R,  1*$R,  0*$R,  1*$R;
    $g.CurveTo: -c*$R, -1*$R, -1*$R, -c*$R, -1*$R,  0*$R;
    $g.CurveTo:  1*$R, -c*$R,  c*$R, -1*$R,  0*$R, -1*$R;
    $g.CurveTo:  c*$R,  1*$R,  1*$R,  c*$R,  1*$R,  0*$R;
    $g.ClosePath;

    $g.Clip;
    $g.EndPath;
    =end comment

    =begin comment
    # draw a local 5-pointed star overflowing the circle
    # first point is at top center
    my $RS = 1.5 * $R;

    my %point;
    # create the proper values for the five points
    my $delta-degrees = 360.0 / 5;
    for 0..^5 -> $i {
        my $degrees = $i * $delta-degrees;
        my $radians = deg2rad($degrees);
        %point{$i}<x> = $RS * sin($radians);
        %point{$i}<y> = $RS * cos($radians);
    }
    $g.MoveTo: %point<0><x>, %point<0><y>; # point 0 (top of the star)
    $g.LineTo: %point<2><x>, %point<2><y>; # point 2
    $g.LineTo: %point<4><x>, %point<4><y>; # point 4
    $g.LineTo: %point<1><x>, %point<1><y>; # point 1
    $g.LineTo: %point<3><x>, %point<3><y>; # point 3
    $g.LineTo: %point<0><x>, %point<0><y>; # point 0
    $g.CloseFillStroke;
    =end comment

    $g.Restore;

} # sub simple-clip1(

sub simple-clip2(
    :$x is copy,
    :$y is copy,
    :$width  is copy,
    :$height is copy,
    :$stroke-color = (color Black),
    :$fill-color   = (color White),
    :$page!,
    :$debug,
    ) is export {

    my $pg-width  = $page.media-box[2];
    my $pg-height = $page.media-box[3];

    # draw a local circle for clipping
    if not ($x.defined and $y.defined) {
        $x = 0.5 * $pg-width;
        $y = 0.5 * $pg-height;
    }
    if not ($width.defined and $height.defined) {
        $width  = 72;
        $height = 72;
    }

    my $radius = 0.5 * $width;
    if $debug {
        say "DEBUG: circle params:";
        say "  x ($x), y ($y), radius ($radius)";
    }

    my $g = $page.gfx;
    $g.Save;

    $g.transform: :translate($x, $y);

    $g.StrokeColor = color Black;
    $g.FillColor   = color White;

    # clip
    draw-circle-clip 0, 0, $radius+60, :clip, :$page, :$debug;

    # stroke it
    draw-circle-clip 0, 0, $radius, :stroke, :$page, :$debug;

    draw-star 0, 0, $radius+30, :stroke, :$page, :$debug;

    $g.Restore;

} # sub simple-clip2(

sub simple-clip3(
    :$x is copy,
    :$y is copy,
    :$width  is copy,
    :$height is copy,
    :$stroke-color = (color Black),
    :$fill-color   = (color White),
    :$page!,
    :$debug,
    ) is export {

    # put the first example on y = 1/4 page height from the top
    # put the second example on y = 2/4 page height from the top
    # put the third example on y = 3/4 page height from the top

    my $pg-width  = $page.media-box[2];
    my $pg-height = $page.media-box[3];

    my $cy1 = 0.75 * $pg-height;
    my $cy2 = 0.50 * $pg-height;
    my $cy3 = 0.20 * $pg-height;

    # title: plain-circle
    $x = 0.5 * $pg-width;
    $y = 0.5 * $pg-height;

    #== first example, no clip
    # draw a colored box
    my $side = 3*72;
    draw-box-clip :llx($x-0.5*$side), :lly($cy1-0.5*$side), :width($side),
                  :height($side), :fill-color(color Blue), :fill, :$page;
    # on top of it draw a white-filled circle
    my $radius = 72;
    draw-circle-clip $x, $cy1, $radius, :fill, :fill-color(color White), :$page;

    $page.gfx.Save;
    #== second example, clip to the circle
    # Note the $page.gfx was NOT saved after the clip so the clipping should be good
    # till the end of the page or after the next .Restore
    draw-circle-clip $x, $cy2, $radius, :clip, :$page;
    draw-box-clip :llx($x-0.5*$side), :lly($cy2-0.5*$side), :width($side),
                  :height($side), :fill-color(color Blue), :fill, :$page;
    $page.gfx.Restore;

    $page.gfx.Save;
    #== third example, clip to the same circle moved down some
    draw-circle-clip $x, $cy3, $radius, :clip, :$page;
    draw-color-wheel :cx($x), :cy($cy3), :radius($radius+10), :$page;

    =begin comment
    draw-hex-wedge :cx($x), :cy($cy3), :height($radius+10), :angle(0),
                   :stroke, :fill, :$page;
    draw-hex-wedge :cx($x), :cy($cy3), :height($radius+10), :angle(60),
                   :stroke, :fill, :$page;
    draw-hex-wedge :cx($x), :cy($cy3), :height($radius+10), :angle(120),
                   :stroke, :fill, :$page;
    draw-hex-wedge :cx($x), :cy($cy3), :height($radius+10), :angle(180),
                   :stroke, :fill, :$page;
    draw-hex-wedge :cx($x), :cy($cy3), :height($radius+10), :angle(240),
                   :stroke, :fill, :$page;
    =end comment

    =begin comment
    draw-box-clip :llx($x-0.5*$side), :lly($cy3-0.5*$side), :width($side), :height($side),
             :fill-color(color Red), :fill, :$page; #, :gfx($page.gfx);
    =end comment

    $page.gfx.Restore;


} # sub simple-clip3(

our %eg-names is export = %(
    # only some have fancy names
    1 => "clipped-box",
    2 => "star-and-circle",
    3 => "plain-circle",
);
sub get-base-name(UInt $N --> Str) is export {
    my $base-name = "example" ~ $N.Str;
    # given an example number, determine a name
    if %eg-names{$N}:exists {
        my $s = %eg-names{$N};
        $base-name = "{$s}-example-$N";
    }
    $base-name
} # sub get-base-name(UInt $N --> Str)

# TODO
# from ps procs in file "boxtext.ps"
# /boxtext { % string location_code [integer: 0-11]
#  (to place--relative to the current point);
# 0 %               center of text bbox positioned at the current point
# 1 %  center of left edge of text bbox positioned at the current point
# 2 %    lower left corner of text bbox positioned at the current point
# 3 % center of lower edge of text bbox positioned at the current point
# 4 %   lower right corner of text bbox positioned at the current point
# 5 % center of right edge of text bbox positioned at the current point
# 6 %   upper right corner of text bbox positioned at the current point
# 7 % center of upper edge of text bbox positioned at the current point
# 8 %    upper left corner of text bbox positioned at the current point
# 9 % on base line (y of current point), left-justified on current point
#10 % on base line (y of current point), centered horizontally
#11 % on base line (y of current point), right-justified on current point

subset Loc of UInt where 0 <= $_ < 12;
sub put-text(
    # based on my PostScript function /puttext
    $x is copy, $y is copy,
    :$text!,
    :$page!,
    # defaults
    :$font-size = 12,
    :$fnt = "t", # key to %fonts, value is the loaded font
    # position of the enclosed text bbox in relation to the current point
Loc :$position = 0, #  where {0 <= $_ < 12},
    # optional constraints
    :$width,
    :$height,
    :$debug,
    ) is export {

    my $font = %fonts{$fnt};
    my PDF::Content::Text::Box $bbox;

    #==========================================
    # Determine text bbox size
    if $width and $height {
        # get constrained box size from PDF::Content
        #   define the applicable set of params affected
        if $position (cont) <0 1 2 3 4 5 6 7 8 9 10 11>.Set {
        }
        $bbox .= new: :$text, :$font, :$font-size, :$width, :$height;
    }
    elsif $height {
        # get constrained box size from PDF::Content
        #   define the applicable set of params affected
        if $position (cont) <0 1 2 3 4 5 6 7 8 9 10 11>.Set {
        }
        $bbox .= new: :$text, :$font, :$font-size, :$height;
    }
    elsif $width {
        # get constrained box size from PDF::Content
        #   define the applicable set of params affected
        if $position (cont) <0 1 2 3 4 5 6 7 8 9 10 11>.Set {
        }
        $bbox .= new: :$text, :$font, :$font-size, :$width;
    }
    else {
        # get natural box size from PDF::Content
        #   define the applicable set of params affected
        if $position (cont) <0 1 2 3 4 5 6 7 8 9 10 11>.Set {
        }
        $bbox .= new: :$text, :$font, :$font-size;
    }

    # Determine location of the text box based on calculated bbox above

    # query the bbox
    my $bwidth  = $bbox.content-width;
    my $bheight = $bbox.content-height;
    my $bllx;
    my $blly;

=begin comment
    $page.graphics: {
        my $tx = $cx;
        my $ty = $cy + ($height * 0.5) - $line1Y;
        .transform: :translate($tx, $ty); # where $x/$y is the desired reference point
        .FillColor = color White; #rgb(0, 0, 0); # color Black
        .font = %fonts<hb>, #.core-font('HelveticaBold'),
                 $line1size; # the size
        .print: $gb, :align<center>, :valign<center>;
    }
=end comment

} # sub label(

sub draw-cross-parts(
    :$x,
    :$y,
    :$width!,
    :$height!,
    :$thick  = 2,
    :$xdelta = 0,
    :$ydelta = 0,
    :$fill   = 1, :$fill-color   = (color White),
    :$stroke = 1, :$stroke-color = (color White),
    :$page!,
    :$debug,
    ) is export {

    my $g = $page.gfx;
    $g.Save;

    # move to x,y and draw the arms with thickness
    # horizontal arm
    my ($llx, $lly);
    $llx = ($x - 0.5*$width) + $xdelta;
    $lly = ($y - 0.5*$thick) + $ydelta;
    draw-rectangle-clip  :$llx, :$lly, :$width, :height($thick), :fill, :$page;

    # verical arm
    $llx = ($x - 0.5*$thick)  + $xdelta;
    $lly = ($y - 0.5*$height) + $ydelta;
    draw-rectangle-clip  :$llx, :$lly, :width($thick), :$height, :fill, :$page;

    $g.Restore;

} # sub draw-cross-parts(

sub place-image(
    $cx, $cy,
    :$image-path!,
    :$page!,
    :$method!,
    :$debug,
    ) is export {

    if not $image-path.IO.r {
        die "FATAL:  Image path '$image-path' cannot be opened.";
    }

    # TODO incorporate an XObject form on pages[0] for reuse. See how to
    # do that in file 'xt/1-xform.t'.
    #

    if $debug {
        note "DEBUG: using image path: $image-path";
    }

    if $method == 1 {
        my PDF::Content::XObject $image .= open: $image-path;
        my $w       = $image.width;
        my $h       = $image.height;
        my $hscaled = $h/30;
        my $wscaled = $w/30;
        my $g = $page.gfx: :trace;
        $g.Save;
        $g.do: $image, :position($cx, $cy), :width($wscaled), :height($hscaled),
                       :valign<center>, :align<center>;
        $g.Restore;
    }
    else {
        die "FATAL: Unable to handle method 2 yet.";
    }
} # sub place-image(

sub write-page-data(
    :$printer,
    :$cx!,
    :$cy!,
    :$side!,
    :$page!,
    :$debug,
    ) is export {
    #==========================================
    # gbumc text in the blue part
    $page.graphics: {
        .transform: :translate($cx, $cy); # where $x/$y is the desired reference point
        .transform: :rotate(deg2rad(90));
        .FillColor = color Black; #rgb(0, 0, 0); # color Black
        .font = %fonts<h>, #.core-font('HelveticaBold'),
                 9; # the size
        .print: "$printer ($side)", :align<center>, :valign<center>;
    }
} #  sub write-page-data(

sub make-printer-test-doc(
) is export {
    # use basic approach from graph paper
} # sub make-printer-test-doc

#===== run/help
# printers
our %printers is export = %(
    1 => "Tom's HP",
    2 => "GBUMC Color",
    3 => "UPS Store (GBZ, near 'little' Walmart)",
    4 => "UPS Store (near Winn-Dixie)",
    5 => "Office Depot (near P'cola Airport)",
);

sub help() is export {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} go | <csv file> [...options...]

    Given a list of names, writes them on reversible paper
      for a two-sided name tag on Letter paper.
    The front side of the first two-sided page will contain
      job details (and the back side will be blank).

    Options:
      1|2    - Select option 1 (original method) or 2
                 (XForm object method), default: 1.

      show   - Gives details of the job based on the input name
               list and card dimension parameters, then exits.
               The information is the same as on the printed job
               cover sheet.

      p=N    - For printer N. See list by number, default: 1 (Tom's HP)

    HERE
    exit
} # sub help() is export

sub run(@args) is export {

    #== from original bin file
    # TODO make more generic before publishing
    my $gbumc-dir = "./examples/GBUMC";
    # TODO create a file name with date and time included
    my $ofile = "Name-tags.pdf";
    # input data file: rose-glass-patterns.dat
    my $gfile = "$gbumc-dir/rose-glass-patterns.dat";
    my @names;
    #my $names-file = "$gbumc-dir/more-names.txt";
    my $names-file = "$gbumc-dir/less-names.txt";
    for $names-file.IO.lines {
        next if $_ ~~ /\h* '#'/;
        my @w = $_.words;
        my $last = @w.pop;
        my $first = @w.shift;
        $first ~= " " ~ @w.pop if @w;
        my $name = "$last $first";
        @names.push: $name;
    }
    @names .= sort;
    #== end chunk from original bin file

    my $show      = 0;
    my $debug     = 0;
    my $landscape = 0;
    my $go        = 0;
    my $clip      = 0;
    my $method    = 1;
    my $printer   = 1;

    for @args {
        when /^ :i s/  { ++$show  }
        when /^ (1|2)/ { $method = +$0 }
        when /^ :i d/  { ++$debug }
        when /^ :i g/  { ++$go    }
        when /^ :i 'p=' (\d) $/ {
            my $pnum = +$0;
            unless %printers{$pnum}:exists {
                say "WARNING: Unknown printer number $pnum.";
                say "  Known printers:";
                my @keys = %printers.keys.sort;
                for @keys -> $k {
                    my $v =  %printers{$k};
                    say "    $k => '$v'";
                }
                exit;
            }
            $printer = %printers{$pnum};
        }
        when /^ :i p $/ {
            say "WARNING: No printer was selected. Use 'p=N'.";
            say "  For N of known printers:";
            my @keys = %printers.keys.sort;
            for @keys -> $k {
                my $v =  %printers{$k};
                say "    $k => '$v'";
            }
            exit;
        }
        default {
            say "Unknown arg '$_'...exiting.";
            exit;
        }
    }

    if $show {
        # TODO make a two-sided page of this:
        my ($nc, $nr, $hgutter, $vgutter) = show-nums;
        say "Badge width (inches):  {%dims<bwi>}";
        say "Badge height (inches): {%dims<bhi>}";

        say "Showing job details for portrait:";
        say "  number of badge columns: $nc";
        say "  number of badge rows:    $nr";
        say "  horizontal gutter space: $hgutter";
        say "  vertical gutter space:   $vgutter";
        say " Total badges: {$nc*$nr}";

        ($nc, $nr, $hgutter, $vgutter) = show-nums 1;
        say "Showing job details for landscape:";
        say "  number of badge columns: $nc";
        say "  number of badge rows:    $nr";
        say "  horizontal gutter space: $hgutter";
        say "  vertical gutter space:   $vgutter";
        say " Total badges: {$nc*$nr}";
        exit;
    }

    # cols 2, rows 4, total 8, portrait
    my @n = @names; # sample name "Mary Ann Deaver"

    my PDF::Lite $pdf .= new;
    $pdf.media-box = [0, 0, %dims<pw>, %dims<ph>];
    my $page;
    my $page-num = 0;
    while @n.elems {

        # a new page of names <= 8
        my @p = @n.splice(0,8); # weird name

        say @p.raku if 0 and $debug;

        say "Working front page..." if $debug;
        # process the front page
        $page = $pdf.add-page;

        # TODO put first and last name found in top margin
        ++$page-num;
        make-badge-page @p, :side<front>, :$page, :$page-num, :$debug,
        :$printer, :project-dir($gbumc-dir), :$method;

        say "Working back page..." if $debug;
        # process the back side of the page
        $page = $pdf.add-page;
        # TODO put first and last name found in top margin
        ++$page-num;
        make-badge-page @p, :side<back>, :$page, :$page-num, :$debug,
        :$printer, :project-dir($gbumc-dir), :$method;
    }

    # add page numbers: Page N of M
    # TODO compress to 300 dpi
    $pdf.save-as: $ofile;
    say "See name tags file: $ofile (using \$method $method)";

} # sub run(@args) is export
