use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;

# The loader and the config options are kept for each program ($0),
# so that two programs called as functions in one process do not share
# the rc file of one another (Command::Run nofork).

my $t = File::Spec->rel2abs('t');
my $home = "$t/home";

$ENV{HOME} = $home;

my %rc = (
    alpha => "option default --alpha-only\n",
    beta  => "option default --beta-only\n",
);
for my $prog (sort keys %rc) {
    my $path = "$home/.${prog}rc";
    open my $fh, '>', $path or die "$path: $!\n";
    print $fh $rc{$prog};
    close $fh;
}
END { unlink "$home/.${_}rc" for keys %rc }

use Getopt::EX::Long qw(:DEFAULT ExConfigure);

my @warn;
local $SIG{__WARN__} = sub { push @warn, @_ };

{
    $0 = "alpha";
    local @ARGV = qw(arg);
    my $alpha;
    ok(GetOptions("alpha-only" => \$alpha), "alpha: GetOptions");
    ok($alpha, "alpha: rc file of alpha is applied");
    is($ARGV[0], "arg", "alpha: args");
}

{
    $0 = "beta";
    local @ARGV = qw(arg);
    my $beta;
    ok(GetOptions("beta-only" => \$beta), "beta: GetOptions");
    ok($beta, "beta: rc file of beta is applied");
    is($ARGV[0], "arg", "beta: args");
    is_deeply(\@warn, [], "beta: rc file of alpha is not applied");
}

{
    $0 = "alpha";
    local @ARGV = qw(arg);
    my $alpha;
    ok(GetOptions("alpha-only" => \$alpha), "alpha again: GetOptions");
    ok($alpha, "alpha again: rc file of alpha is still applied");
    is_deeply(\@warn, [], "alpha again: no warning");
}

# ExConfigure sets the config options of the current program
{
    $0 = "alpha";
    ExConfigure(BASECLASS => 'Alpha::Base');
    is(Getopt::EX::Long::config_option()->{BASECLASS}, 'Alpha::Base',
       "ExConfigure: alpha");
    $0 = "beta";
    isnt(Getopt::EX::Long::config_option()->{BASECLASS} // '', 'Alpha::Base',
	 "ExConfigure: beta is not affected");
}

done_testing;
