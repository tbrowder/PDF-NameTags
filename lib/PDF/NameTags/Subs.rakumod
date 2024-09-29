unit module PDF::NameTags::Subs;

sub get-text-chunks(
    :$name = "some printer",
    :$media!,
    :$debug,
    --> Hash
    ) is export {

    # define the HERE docs outside the hash
    my $info1 = q:to/HERE/;
                # center this block on its longest line
                HERE
    my $text1 = qq:to/HERE/;
                Printer Test Page

                Printer: {$name}


                Instructions
                HERE

    my $info2 = q:to/HERE/;
                # center this block on its longest line
                HERE
    my $text2 = q:to/HERE/;
                The following settings are often the defaults, but
                please ensure they are correct, or the output cannot
                be used for the proper creation of two-sided name
                tags.
                HERE

    my $info3 = q:to/HERE/;
                # center this block on its longest line
                HERE
    my $text3 = q:to/HERE/;
                1. Do not use scaling (or set scaling = 100%).
                2. Select two-sided printing (flip on long side).
                3. Select 'Portrait' orientation.
                HERE

    my $info4 = q:to/HERE/;
                HERE
    my $text4 = q:to/HERE/;
                Printer: $name
                Media:   {$media}

                HERE

    my %h = %(
        1 => {
            name => "chunk1",
            info => $info1,
            text => $text1,
        },

        2 => {
            name => "chunk2",
            info => $info2,
            text => $text2,
        },
        3 => {
            name => "howto",
            info => $info3,
            text => $text3,
        },
        4 => {
            name => "printer-info",
            info => $info4,
            text => $text4,
        },
    );

    %h;
}
