use Test;

use FontFactory;
use FontFactory::FontClasses;
use FontFactory::Config;

is 1, 1, "dummy test place holder";
is 1, 1, "MUST ROUNDTRIP FontClass and Config file";

my $test-dir = "t/home";
create-config :$test-dir;


