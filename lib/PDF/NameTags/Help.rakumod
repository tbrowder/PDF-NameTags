unit module PDF::NameTags::Help;

=finish
# printers
our %printers is export = %(
    1 => "Tom's HP",
    2 => "GBUMC Color",
    3 => "UPS Store (GBZ, near 'little' Walmart)",
    4 => "UPS Store (near Winn-Dixie)",
    5 => "Office Depot (near P'cola Airport)",
);

sub help($program) is export {
    print qq:to/HERE/;
    Usage: {$program.basename} go | <csv file> [...options...]

    Given a list of names, writes them on reversible paper
      for a two-sided name tag on Letter paper.
    The front side of the first two-sided page will contain
      job details (and the back side will be blank).

    Options:
      1|2    - Select option one (original method) or two
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
} # sub run(@args) is export
