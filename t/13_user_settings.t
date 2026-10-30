use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;

# USER_SETTINGS => 0 stops a program from reading its rc file.  It can
# be set for the program itself, for another program by name (PROGRAM
# => name, for a program called as a function in this process), or
# through the environment variable GETOPTEX_NO_USER_SETTINGS.

my $t = File::Spec->rel2abs('t');
my $home = "$t/home";

$ENV{HOME} = $home;
delete $ENV{GETOPTEX_NO_USER_SETTINGS};

my @progs = map { "us$_" } 1..10;
for my $prog (@progs) {
    my $path = "$home/.${prog}rc";
    open my $fh, '>', $path or die "$path: $!\n";
    print $fh "option default --${prog}-only\n";
    close $fh;
}
END { unlink "$home/.${_}rc" for @progs }

use Getopt::EX::Long qw(:DEFAULT ExConfigure);

my @warn;
local $SIG{__WARN__} = sub { push @warn, @_ };

# Run GetOptions for the program and return the value of the option
# that only the rc file sets.
sub rc_applied {
    my $prog = shift;
    $0 = shift // $prog;
    local @ARGV = qw(arg);
    my $flag;
    ok(GetOptions("${prog}-only" => \$flag), "$prog: GetOptions");
    is($ARGV[0], "arg", "$prog: args");
    $flag;
}

# control: the rc file is read by default
ok(rc_applied('us1'), "us1: rc file is applied by default");

# the program turns off its own rc file
{
    $0 = 'us2';
    ExConfigure(USER_SETTINGS => 0);
    ok(!rc_applied('us2'), "us2: USER_SETTINGS => 0 stops the rc file");
}

# another program is configured by name, the current one is not affected
{
    $0 = 'us3';
    ExConfigure(PROGRAM => 'us4', USER_SETTINGS => 0);
    is(Getopt::EX::Long::config_option()->{USER_SETTINGS}, 1,
       "us3: PROGRAM => us4 leaves us3 alone");
    is(Getopt::EX::Long::config_option('us4')->{USER_SETTINGS}, 0,
       "us4: configured from us3");
    ok(rc_applied('us3'), "us3: rc file is still applied");
    ok(!rc_applied('us4'), "us4: rc file is not applied");
}

# the program name is the basename of $0
{
    $0 = 'us5';
    ExConfigure(PROGRAM => 'us6', USER_SETTINGS => 0);
    ok(!rc_applied('us6', '/usr/local/bin/us6'), "us6: full path in \$0");
}

# an explicitly configured RCFILE is dropped as well
{
    $0 = 'us7';
    ExConfigure(RCFILE => "$home/.us7rc", USER_SETTINGS => 0);
    ok(!rc_applied('us7'), "us7: explicit RCFILE is dropped");
}

# object interface
{
    $0 = 'us8';
    ExConfigure(USER_SETTINGS => 0);
    my $parser = Getopt::EX::Long::Parser->new();
    local @ARGV = qw(arg);
    my $flag;
    ok($parser->getoptions("us8-only" => \$flag), "us8: Parser getoptions");
    ok(!$flag, "us8: Parser does not read the rc file");
}
{
    $0 = 'us9';
    my $parser = Getopt::EX::Long::Parser->new(
	exconfig => [ BASECLASS => 'App::us9',
		      USER_SETTINGS => 0, RCFILE => "$home/.us9rc" ],
    );
    local @ARGV = qw(arg);
    my $flag;
    ok($parser->getoptions("us9-only" => \$flag), "us9: Parser getoptions");
    ok(!$flag, "us9: USER_SETTINGS in exconfig drops RCFILE");
}

is_deeply(\@warn, [], "no warnings so far");

# environment variable: names
{
    local $ENV{GETOPTEX_NO_USER_SETTINGS} = 'us10, other';
    ok(!rc_applied('us10'), "us10: named in GETOPTEX_NO_USER_SETTINGS");
    Getopt::EX::Long::ExReset();
    ok(rc_applied('us1'), "us1: not named, rc file is applied");
}

# environment variable: all
{
    Getopt::EX::Long::ExReset();
    local $ENV{GETOPTEX_NO_USER_SETTINGS} = '1';
    ok(!rc_applied('us1'), "us1: GETOPTEX_NO_USER_SETTINGS=1 stops all");
}

# environment variable: empty or 0 has no effect
{
    for my $val ('', '0') {
	Getopt::EX::Long::ExReset();
	local $ENV{GETOPTEX_NO_USER_SETTINGS} = $val;
	ok(rc_applied('us1'), "us1: GETOPTEX_NO_USER_SETTINGS='$val' has no effect");
    }
}

is_deeply(\@warn, [], "no warnings");

done_testing;
