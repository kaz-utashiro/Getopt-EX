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
    my $rc_content = "option default --default_inrc\n";
    my $rc_path = "t/home/.examplerc";
    my $fh = IO::File->new(">$rc_path") or die "$rc_path: $!\n";
    print $fh $rc_content;
    $fh->close;

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

    unlink $rc_path or warn "$rc_path: $!\n";
}

{
    use Getopt::EX::Long qw(Configure);

    is($REQUIRE_ORDER,
       $Getopt::Long::REQUIRE_ORDER,
       "\$REQUIRE_ORDER = $REQUIRE_ORDER");
    is($PERMUTE,
       $Getopt::Long::PERMUTE,
       "\$PERMUTE = $PERMUTE");
    is($RETURN_IN_ORDER,
       $Getopt::Long::RETURN_IN_ORDER,
       "\$RETURN_IN_ORDER = $RETURN_IN_ORDER");

    Configure("require_order");
    is($Getopt::Long::order, $REQUIRE_ORDER, "Configure require_order");

    Configure("permute");
    is($Getopt::Long::order, $PERMUTE, "Configure permute");
}

done_testing;
