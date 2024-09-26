use Test;

use PDF::GraphPaper;
use PDF::NameTags;
use File::Temp;

my $debug = 0; # unless debug is set, you cannot see the output file
my $tdir;

if $debug {
    $tdir = "/tmp/t";
    mkdir $tdir;
}
else {
    $tdir = tempdir;
}

plan 1;

lives-ok {
    my PDF::GraphPaper $description .= new;
    my $ofil = "$tdir/t.pdf";
    make-graph-paper $ofil, :$description;
}, "sub make-graph-paper lives-ok";
