package Getopt::EX::Long;

our $VERSION = "3.04";

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
		   '&ExReset',
    );
use parent qw(Getopt::Long);

use Data::Dumper;
use Getopt::Long();
use Getopt::EX::Loader;
use Getopt::EX::Func qw(parse_func);

my %DefaultConfigOption = ( AUTO_DEFAULT => 1, USER_SETTINGS => 1 );
my @ValidOptions = (qw(AUTO_DEFAULT USER_SETTINGS), @Getopt::EX::Loader::OPTIONS);

# The config options and the loader belong to a program, whose name
# ($0) determines the rc file and the base class.  They are kept for
# each program name, so that programs called as functions in one
# process (Command::Run nofork, for example) do not share them.
my %ConfigOption;
my %Loader;
my $loader_pid = $$;  # Set at module load time for fork detection

sub ExReset {
    %ConfigOption = ();
    %Loader = ();
    $loader_pid = $$;
}

# Name of the program: the basename of $0 or the given path
sub prog_name {
    my $path = @_ ? shift : $0;
    $path =~ m{([^/]+)$} ? $1 : $path;
}

# True when the environment says that the program should not read
# user settings: GETOPTEX_NO_USER_SETTINGS is 1 or * for all programs,
# or a list of program names separated by spaces or commas.
sub env_no_user_settings {
    my $prog = shift;
    my $env = $ENV{GETOPTEX_NO_USER_SETTINGS} // return 0;
    return 0 if $env eq '' or $env eq '0';
    return 1 if $env eq '1' or $env eq '*';
    scalar grep { $_ eq $prog } split /[\s,]+/, $env;
}

# Config options of the current program, or of the named one
sub config_option {
    my $prog = prog_name(@_);
    ExReset() if $loader_pid != $$;
    $ConfigOption{$prog} //= {
	%DefaultConfigOption,
	env_no_user_settings($prog) ? (USER_SETTINGS => 0) : (),
    };
}

# Options for Getopt::EX::Loader->new from the config options.  RCFILE
# is dropped when the program does not read user settings.
sub loader_options {
    my $config = shift;
    my %opt = map {
	exists $config->{$_} ? ( $_ => $config->{$_} ) : ()
    } @Getopt::EX::Loader::OPTIONS;
    delete $opt{RCFILE} unless $config->{USER_SETTINGS};
    %opt;
}

sub GetOptions {
    unshift @_, \@ARGV;
    goto &GetOptionsFromArray;
}

sub GetOptionsFromArray {
    my $argv = $_[0];

    my $config = config_option();

    set_default($config) if $config->{AUTO_DEFAULT};

    my $loader = $Loader{prog_name()} //= Getopt::EX::Loader->new(loader_options($config));

    $loader->deal_with($argv);

    my @builtins = do {
	if (ref $_[1] eq 'HASH') {
	    $loader->hashed_builtins($_[1]);
	} else {
	    $loader->builtins;
	}
    };
    push @_, @builtins;

    # Suppress "Duplicate specification" warnings from Getopt::Long
    local $SIG{__WARN__} = sub {
	warn @_ unless $_[0] =~ /^Duplicate specification/;
    };
    Getopt::Long::GetOptionsFromArray(@_);
}

sub GetOptionsFromString {
    die "GetOptionsFromString is not supported, yet.\n";
}

sub ExConfigure {
    my %opt = @_;
    my $config = config_option(delete $opt{PROGRAM} // $0);
    for my $name (@ValidOptions) {
	if (exists $opt{$name}) {
	    $config->{$name} = delete $opt{$name};
	}
    }
    warn "Unknown option: ", Dumper \%opt if %opt;
}

sub set_default {
    my $config = shift;
    use List::Util qw(pairmap);
    pairmap { $config->{$a} //= $b } get_default();
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
    my $config = Getopt::EX::Long::config_option();
    if (@exconfig == 0 and $config->{AUTO_DEFAULT}) {
	@exconfig = Getopt::EX::Long::get_default();
    }
    my %exconfig = @exconfig;
    if (exists $exconfig{USER_SETTINGS}) {
	$config->{USER_SETTINGS} = delete $exconfig{USER_SETTINGS};
    }
    delete $exconfig{RCFILE} unless $config->{USER_SETTINGS};
    @exconfig = %exconfig;

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

    # Suppress "Duplicate specification" warnings from Getopt::Long
    local $SIG{__WARN__} = sub {
	warn @_ unless $_[0] =~ /^Duplicate specification/;
    };
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

=item USER_SETTINGS

Whether to read the startup rc file of the program, F<~/.>I<prog>F<rc>
or the file given by B<RCFILE>.  Defaults to 1.  When set to 0, the
rc file is not read.  Modules loaded with B<-M> and their default
options are not affected.  The environment variable
B<GETOPTEX_NO_USER_SETTINGS> sets it to 0 from outside of the
program (see L</ENVIRONMENT>).

A program which takes default options from somewhere else than the
rc file can skip them as well; see B<config_option>.

=item PROGRAM

Not a config option itself, but names the program whose config
options are set by this B<ExConfigure> call.  Default is the current
program, the basename of C<$0>.

This is for a program which calls another program as a function in
the same process, as L<Command::Run> does in its nofork mode: the
callee reads its own rc file, because its config options are kept
apart from those of the caller (see L</PROGRAM STATE>).  The rc file
holds the settings of the user for the callee run from the command
line, and the output of the caller should not depend on them.  The
caller turns them off for the callee by name, before the first
B<GetOptions> call of the callee:

  ExConfigure(PROGRAM => 'ansicolumn', USER_SETTINGS => 0);

=back

Other options including B<RCFILE> and B<BASECLASS> are passed to
B<Getopt::EX::Loader>.  Read its documentation for details.

=head1 FUNCTIONS

=over 4

=item B<ExConfigure>

Set config options.  See L</CONFIG OPTIONS>.

=item B<ExReset>

Reset the internal loader and configuration to their default state.
This is useful when you need to reinitialize the module state, for
example after forking a child process.

Note that B<ExConfigure> and B<GetOptionsFromArray> automatically
detect forked processes and reset internally, so explicit calls to
B<ExReset> are usually unnecessary.

=item B<config_option> [ I<program> ]

Return the hash reference to the config options of the current
program, or of the named one.

Some programs take default options from an environment variable as
well, as B<greple> does with C<GREPLEOPTS>.  This module does not
handle such variables, but the program can read C<USER_SETTINGS>
through this function and skip them when it is 0, along with the rc
file:

  if (Getopt::EX::Long::config_option()->{USER_SETTINGS}) {
      unshift @ARGV, shellwords($ENV{GREPLEOPTS} // '');
  }

=back

=head1 ENVIRONMENT

=over 4

=item GETOPTEX_NO_USER_SETTINGS

Set B<USER_SETTINGS> to 0 for the programs named in it, separated by
spaces or commas, or for every program when it is C<1> or C<*>, as
far as the programs read their rc file through this module.  Use it
to run programs without the settings of the user, in tests or in a
container, and to reach programs which are started as separate
processes.  It is read when the config options of a program are first
used, so it has to be set before that.

=back

=head1 PROGRAM STATE

The config options and the loader (which holds the rc file and the
modules loaded) belong to the program, whose name C<$0> determines the
default rc file and base class.  They are kept for each program
name, the basename of C<$0>: when C<$0> is changed, as
L<Command::Run> does to call a program as a function without forking,
B<ExConfigure> and B<GetOptions> work on the state of that program,
and the rc file of one program is not applied to another.

The state of a program is created when it is first used, and the
loader is created at its first B<GetOptions> call and kept.  Config
options given for a program afterwards, with B<PROGRAM> or through the
environment, do not change the loader which has already read the rc
file.  When the process is forked, the state is reset in the child, so
a caller should set the config options of the callee right before
calling it.

=head1 INCOMPATIBILITY

The subroutine B<GetOptionsFromString> is not supported.

=head1 SEE ALSO

L<Getopt::EX>,
L<Getopt::EX::Module>,
L<Getopt::EX::Loader>
