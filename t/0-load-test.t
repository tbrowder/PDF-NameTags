# copied from @finanalyst
use v6.d;
use Test;

my @modules = <
    NameTags
    GraphPaper
    NameTags::FreeFonts
    NameTags::Subs
    NameTags::Vars
>;

plan @modules.elems;

for @modules {
    use-ok "PDF::$_", "Module $_ can be used";
}

