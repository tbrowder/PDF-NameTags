use Test;

use File::Find;

my $debug = 0;

is 1, 1;

done-testing;

=finish

my $topdir = "./xt/tmp";
my @t0dirs = <dir00 dir01 dir02>;
my @t1dirs = <dir10 dir11 dir12>;

mkdir $topdir;
my $par = 3;
for @t0dirs -> $d0 {
    mkdir("$topdir/$d0");
    for @t1dirs -> $d1 {
        mkdir("$topdir/$d0/$d1");
        my $p = $d1.IO.parent($par);
        say $p;;
    }
}

my @dirs = find :dir($topdir), :type<dir>;
say "Dirs under '$topdir'";
for @dirs {
    say "  $_";
}


#=begin comment
END {
    shell "rm -rf $topdir";
}
#=end comment

=finish

# compare /resources and META6.json
my %m = from-json "META6.json".IO.slurp;

# the files in /resources WITHOUT 'resources' in their paths
my @mfils = @(%m<resources>);
if $debug {
    say "Files in \%meta<resources>:";
    say "  $_"  for @mfils.sort;
}

# the files in /resources WITH 'resources' in their paths
my @rfils = find :dir("resources"), :type<file>;
if $debug {
    say "Files in /resources:";
    say "  $_" for @rfils.sort;
}

# get the top-level dir 
my @rdirs = find :dir("resources"), :type<dir>;
if $debug {
    my $nrdirs = @rdirs.elems;
    if $nrdirs {
        say "Subdirectories in /resources:";
        say "  $_" for @rdirs.sort;
    }
    else {
        say "There are NO subdirectories in /resources";
    }
}

=finish
