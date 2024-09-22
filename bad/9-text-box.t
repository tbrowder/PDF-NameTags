use Test;

use PDF::Lite;
use PDF::Content;
use PDF::Content::Text::Box;
use PDF::Font::Loader :load-font;

my $file = "dev/fonts/FreeSerif.otf";
my $font = PDF::Font::Loader.load-font: :$file;
my $font-size = 12;
my $sf = $font-size/1000.0;
say "font scale factor (font-size / 1000): ", $sf;
my $height = 20;
my $text = "To Wit, yo";
my $position = [0, 0];
my $text-box = PDF::Content::Text::Box.new: :$text, :$font, :$font-size,
                    :$height;
my $y = $text-box.content-height;
my $x = $text-box.content-width;
my $h = $font.height;
my $sw = $font.stringwidth: $text, $font-size; # kern?
my $swu = $font.stringwidth: $text; # kern?
say "content-width: ", $x;
say "content-height: ", $y;
say "font height (leading): ", $h;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;

my @bbox;
$page.text: {
    .text-position = 0, 0;
    @bbox = .print: $text-box;
}
say @bbox.gist;
say "stringwidth (scaled): ", $sw;
say "stringwidth (unscaled): ", $swu;
say "stringwidth (unscaled * sf): ", $swu * $sf;

is 1, 1;

done-testing;

=finish

my $b = PDF::Content::Text::Box.new(;

my $ff = FontFactory.new;
my $df = $ff.get-font: 1, 12;

is $df.size, 12;

my $text = "Some text";
my $o = $df.string: $text;
is $o.text, $text;

# TODO use a text box to check output from FontFactory
#      a simple bbox should work

done-testing;

