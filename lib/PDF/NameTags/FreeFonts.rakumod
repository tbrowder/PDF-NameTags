unit module PDF::NameTags::FreeFonts;

use PDF::Font::Loader::HarfBuzz;
use PDF::Font::Loader :load-font;
use PDF::Content;

use QueryOS;

my $os = OS.new;

my $Ld = "/usr/share/fonts/opentype/freefont";
my $Md = "/opt/homebrew/Caskroom/font-freefont/20120503/freefont-20120503";
my $Wd = "/usr/share/fonts/opentype/freefont";

sub get-loaded-fonts-hash(:$debug --> Hash) is export {
    my $fontdir;
    if $os.is-linux {
        $fontdir = $Ld;
    }
    elsif $os.is-macos {
        $fontdir = $Md;
    }
    elsif $os.is-windows {
        $fontdir = $Wd;
    }
    else {
        die "FATAL: Unable to determine your operating system (OS)";
    }

    # the Free Font collection
    # fonts needed
    my $fft   = "$fontdir/FreeSerif.otf";
    my $fftb  = "$fontdir/FreeSerifBold.otf";
    my $ffti  = "$fontdir/FreeSerifItalic.otf";
    my $fftbi = "$fontdir/FreeSerifBoldItalic.otf";

    my $ffh   = "$fontdir/FreeSans.otf";
    my $ffhb  = "$fontdir/FreeSansBold.otf";
    my $ffho  = "$fontdir/FreeSansOblique.otf";
    my $ffhbo = "$fontdir/FreeSansBoldOblique.otf";
 
    my $ffc   = "$fontdir/FreeMono.otf";
    my $ffcb  = "$fontdir/FreeMonoBold.otf";
    my $ffco  = "$fontdir/FreeMonoOblique.otf";
    my $ffcbo = "$fontdir/FreeMonoBoldOblique.otf";

    my %fonts;
    %fonts<t>   = load-font :file($fft); # deb 12, :subset;
    %fonts<tb>  = load-font :file($fftb); # deb 12, :subset;
    %fonts<ti>  = load-font :file($ffti); # deb 12, :subset;
    %fonts<tbi> = load-font :file($fftbi); # deb 12, :subset;

    %fonts<h>   = load-font :file($ffh); # deb 12, :subset;
    %fonts<hb>  = load-font :file($ffhb); # deb 12, :subset;
    %fonts<ho>  = load-font :file($ffho); # deb 12, :subset;
    %fonts<hbo> = load-font :file($ffhbo); # deb 12, :subset;

    %fonts<c>   = load-font :file($ffc); # deb 12, :subset;
    %fonts<cb>  = load-font :file($ffcb); # deb 12, :subset;
    %fonts<co>  = load-font :file($ffco); # deb 12, :subset;
    %fonts<cbo> = load-font :file($ffcbo); # deb 12, :subset;

    %fonts;
}

