package Getopt::EX::Long;

our $VERSION = "3.00";

use v5.14;
use warnings;
use Carp;

{
    no warnings 'once';
    *REQUIRE_ORDER   = \$Getopt::Long::REQUIRE_ORDER;
    *PERMUTE         = \$Getopt::Long::PERMUTE;
    *RETURN_IN_ORDER = \$Getopt::Long::RETURN_IN_ORDER;

    *Configure       = \&Getopt::Long::Configure;
    *HelpMessage     = \&Getopt::Long::HelpMessage;
    *VersionMessage  = \&Getopt::Long::VersionMessage;
}

use Exporter 'import';
our @EXPORT    = qw(&GetOptions $REQUIRE_ORDER $PERMUTE $RETURN_IN_ORDER);
our @EXPORT_OK = ( '&GetOptionsFromArray',
		 # '&GetOptionsFromString',
		   '&Configure',
		   '&HelpMessage',
		   '&VersionMessage',
		   '&ExConfigure',
    );
use parent qw(Getopt::Long);

use Data::Dumper;
use Getopt::Long();
use Getopt::EX::Loader;
use Getopt::EX::Func qw(parse_func);

my %ConfigOption = ( AUTO_DEFAULT => 1 );
my @ValidOptions = ('AUTO_DEFAULT' , @Getopt::EX::Loader::OPTIONS);

my $loader;

sub GetOptions {
    unshift @_, \@ARGV;
    goto &GetOptionsFromArray;
}

sub GetOptionsFromArray {
    my $argv = $_[0];

    set_default() if $ConfigOption{AUTO_DEFAULT};

    $loader //= Getopt::EX::Loader->new(do {
	map {
	    exists $ConfigOption{$_} ? ( $_ => $ConfigOption{$_} ) : ()
	} @Getopt::EX::Loader::OPTIONS
    });

    $loader->deal_with($argv);

    my @builtins = do {
	if (ref $_[1] eq 'HASH') {
	    $loader->hashed_builtins($_[1]);
	} else {
	    $loader->builtins;
	}
    };
    push @_, @builtins;

    goto &Getopt::Long::GetOptionsFromArray;
}

sub GetOptionsFromString {
    die "GetOptionsFromString is not supported, yet.\n";
}

sub ExConfigure {
    my %opt = @_;
    for my $name (@ValidOptions) {
	if (exists $opt{$name}) {
	    $ConfigOption{$name} = delete $opt{$name};
	}
    }
    warn "Unknown option: ", Dumper \%opt if %opt;
}

sub set_default {
    use List::Util qw(pairmap);
    pairmap { $ConfigOption{$a} //= $b } get_default();
}

sub get_default {
    my @list;

    my $prog = ($0 =~ /([^\/]+)$/) ? $1 : return ();

    if (defined (my $home = $ENV{HOME})) {
	if (-f (my $rc = "$home/.${prog}rc")) {
	    push @list, RCFILE => $rc;
	}
    }

    push @list, BASECLASS => "App::$prog";

    @list;
}

1;

############################################################

package Getopt::EX::Long::Parser;

use strict;
use warnings;

use List::Util qw(first);
use Data::Dumper;

use Getopt::Long();  # Load first to make Getopt::Long::Parser available
use parent -norequire, qw(Getopt::Long::Parser);

use Getopt::EX::Loader;

sub new {
    my $class = shift;

    my @exconfig;
    while (defined (my $i = first { $_[$_] eq 'exconfig' } keys @_)) {
	push @exconfig, @{ (splice @_, $i, 2)[1] };
    }
    if (@exconfig == 0 and $ConfigOption{AUTO_DEFAULT}) {
	@exconfig = Getopt::EX::Long::get_default();
    }

    my $obj = $class->SUPER::new(@_);

    my $loader = $obj->{exloader} = Getopt::EX::Loader->new(@exconfig);

    $obj;
}

sub getoptionsfromarray {
    my $obj = shift;
    my $argv = $_[0];
    my $loader = $obj->{exloader};

    $loader->deal_with($argv);

    my @builtins = do {
	if (ref $_[1] eq 'HASH') {
	    $loader->hashed_builtins($_[1]);
	} else {
	    $loader->builtins;
	}
    };
    push @_, @builtins;

    $obj->SUPER::getoptionsfromarray(@_);
}

1;

=head1 NAME

Getopt::EX::Long - Getopt::Long compatible extended module

=head1 SYNOPSIS

  use Getopt::EX::Long;
  GetOptions("file=s" => \my $file);

or using the object-oriented interface:

  use Getopt::EX::Long;
  my $parser = Getopt::EX::Long::Parser->new(
      config   => [ qw(posix_default no_ignore_case) ],
      exconfig => [ BASECLASS => 'App::example' ],
  );
  $parser->getoptions("file=s" => \my $file);

=head1 DESCRIPTION

L<Getopt::EX::Long> is almost fully compatible with L<Getopt::Long>.
You can replace the module declaration, and it should work the same as
before (see L</INCOMPATIBILITY>).

In addition to standard L<Getopt::Long> functionality, users can
define their own option aliases and write dynamically loaded extension
modules.  If the command name is I<example>, the file

    ~/.examplerc

is loaded by default.  In this rc file, users can define option
aliases with macro processing.  This is useful when the command takes
complex arguments.

Special options starting with B<-M> load the corresponding Perl
module.  The module is assumed to be under a specific base class.  For
example:

    % example -Mfoo

loads the C<App::example::foo> module by default.

Since extension modules are normal Perl modules, users can write any
code they need.  If the module is specified with an initial function
call, that function is called when the module is loaded:

    % example -Mfoo::bar(buz=100)

This loads module B<foo> and calls function I<bar> with the parameter
I<buz> set to 100.

If the module includes a C<__DATA__> section, it is interpreted as an
rc file.  Combined with the startup function call, this allows module
behavior to be controlled through user-defined options.

For details about rc files and module specification, see
L<Getopt::EX::Module>.

=head1 CONFIG OPTIONS

Config options are set by B<ExConfigure> or the B<exconfig>
parameter for the B<Getopt::EX::Long::Parser::new> method.

=over 4

=item AUTO_DEFAULT

Config options B<RCFILE> and B<BASECLASS> are automatically set based
on the name of the command executable.  If you don't want this behavior,
set B<AUTO_DEFAULT> to 0.

=back

Other options including B<RCFILE> and B<BASECLASS> are passed to
B<Getopt::EX::Loader>.  Read its documentation for details.

=head1 INCOMPATIBILITY

The subroutine B<GetOptionsFromString> is not supported.

=head1 SEE ALSO

L<Getopt::EX>,
L<Getopt::EX::Module>,
L<Getopt::EX::Loader>
