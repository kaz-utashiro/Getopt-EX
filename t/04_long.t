use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;
use Data::Dumper;

my $lib = File::Spec->rel2abs('lib');
my $t = File::Spec->rel2abs('t');
my $home = "$t/home";
my $app_lib = "$home/lib";

$ENV{HOME} = $home;
unshift @INC, $app_lib;

##
## GetOptions
##
{
    $0 = "/usr/bin/example";
    use Getopt::EX::Long;
    local @ARGV = qw(-Mexample_test --drink-me arg1);
    my $default;
    my $default_inrc;
    GetOptions(
	"default" => \$default,
	"default_inrc" => \$default_inrc,
	);
    ok($default, "--default");
    ok($default_inrc, "--default_inrc");
    is($ARGV[0], "poison", "args");
}

done_testing;
