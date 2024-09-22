#!/bin/env raku

my $f1    = 'pdf-checker.raku';
my $args1 = '--render --strict';
my $f2    = 'pdf-content-dump.raku';
my $args2 = '--raku';

if not @*ARGS {
    print qq:to/HERE/;
    Usage: {$*PROGRAM.basename} <pdf file> [...options...]

    Given an input PDF file, runs two of David Warring's
      PDF checking scripts which are installed along with
      modules 'PDF::Class' and 'PDF::Content':
        {$f1} {$args1} <pdf file>
        {$f2} {$args2} <pdf file>

    HERE
    exit
}

