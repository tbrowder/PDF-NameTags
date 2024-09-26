unit class PDF::GraphPaper is export;

has $.units = "in";     # default
has $.media = "letter"; # default
#=========================
#== defaults for Letter paper
has $.margins   = 0.4; # * 72;
has $.cell-size = 0.1; # desired minimum cell size (inches)

my $.cells-per-grid = 10;  # heavier line every X cells

# in PS points
my $.cell-linewidth     =  0;    # very fine line
my $.mid-grid-linewidth =  0.75; # heavier line width (every 5 cells)
my $.grid-linewidth     =  1.40; # heavier line width (every 10 cells)
#=========================

submethod TWEAK {
    # adjust measurements to PS points
    if $!units    ~~ /^ :i in / {
        $!margins   *= 72;
        $!cell-size *= 72;
    }
    elsif $!units ~~ /^ :i cm / {
        my $cm-per-in = 2.54;
        my $in-per-cm = 1.0 / $cm-per-in;

        $!margins   *= 72 * $in-per-cm;
        $!cell-size *= 72 * $in-per-cm;
    }
    elsif $!units ~~ /^ :i mm / {
        my $cm-per-in = 2.54;
        my $mm-per-cm = 100;
        my $mm-per-in = $cm-per-in * $mm-per-cm;
        my $in-per-mm = 1.0 / $mm-per-in;

        $!margins   *= 72 * $mm-per-in;
        $!cell-size *= 72 * $mm-per-in;
    }
    elsif $!units ~~ /^ :i [p|ps|po|poi|poin|point|points] / {
        # already in PS points
        ; # no-op
    }
    else {
        die qq:to/HERE/;
        FATAL: Unrecognized length unit '$_'. If $_ is a valid length
        unit, please file an issue.
        HERE
    }
}
