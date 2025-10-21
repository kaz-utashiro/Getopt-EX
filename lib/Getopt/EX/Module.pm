package Getopt::EX::Module;

our $VERSION = "2.3.1";

use v5.14;
use warnings;
use Carp;

use Exporter 'import';
our @EXPORT      = qw();
our %EXPORT_TAGS = ( );
our @EXPORT_OK   = qw();

use Data::Dumper;
use Text::ParseWords qw(shellwords);
use List::Util qw(first pairmap);

use Getopt::EX::Func qw(parse_func);

sub new {
    my $class = shift;
    my $obj = bless {
	Module => undef,
	Base => undef,
	Mode => { FUNCTION => 0, WILDCARD => 0 },
	Define => [],
	Expand  => [],
	Option => [],
	Builtin => [],
	Automod => [],
	Autoload => {},
	Call => [],
	Help => [],
    }, $class;

    configure $obj @_ if @_;

    $obj;
}

sub configure {
    my $obj = shift;
    my %opt = @_;

    if (my $base = delete $opt{BASECLASS}) {
	$obj->{Base} = $base;
    }

    if (my $file = delete $opt{FILE}) {
	if (open my $fh, "<:encoding(utf8)", $file) {
	    $obj->module($file);
	    $obj->readrc($fh);
	}
    }
    elsif (my $module = delete $opt{MODULE}) {
	my $pkg = $opt{PACKAGE} || 'main';
	my @base = do {
	    if (ref $obj->{Base} eq 'ARRAY') {
		@{$obj->{Base}};
	    } else {
		($obj->{Base} // '');
	    }
	};
	while (@base) {
	    my $base = shift @base;
	    my $mod = $base ? "$base\::$module" : $module;
	    my $path = $mod =~ s{::}{/}gr . ".pm";
	    eval "package $pkg; use $mod;";
	    if ($@) {
		next if @base and $@ =~ /Can't locate \Q$path\E/;
		croak "$mod: $@";
	    }
	    $obj->module($mod);
	    $obj->define('__PACKAGE__' => $mod);
	    local *data = "$mod\::DATA";
	    if (not eof *data) {
		my $pos = tell *data;
		$obj->readrc(*data);
		# recover position in case called multiple times
		seek *data, $pos, 0 or die "seek: $!" if $pos >= 0;
	    }
	    last;
	}
    }

    if (my $builtin = delete $opt{BUILTIN}) {
	$obj->builtin(@$builtin);
    }

    warn "Unprocessed option: ", Dumper \%opt if %opt;

    $obj;
}

sub readrc {
    my $obj = shift;
    my $fh = shift;
    my $text = do { local $/; <$fh> };
    for ($text) {
	s/^__(?:CODE|PERL5?)__\s*\n(.*)//ms and do {
	    package main;
	    no warnings 'once';
	    local $main::MODULE = $obj;
	    eval $1;
	    die if $@;
	};
	s/^\s*(?:#.*)?\n//mg;
	s/\\\n//g;
    }
    $obj->parsetext($text);
    $obj;
}

############################################################

sub module {
    my $obj = shift;
    @_  ? $obj->{Module} = shift
	: $obj->{Module} // '';
}

sub title {
    my $obj = shift;
    my $mod = $obj->module;
    $mod =~ m{ .* [:/] (.+) }x ? $1 : $mod;
}

sub define {
    my $obj = shift;
    my $name = shift;
    my $list = $obj->{Define};
    if (@_) {
	my $re = qr/\Q$name/;
	unshift(@$list, [ $name, $re, shift ]);
    } else {
	first { $_->[0] eq $name } @$list;
    }
}

sub expand {
    my $obj = shift;
    local *_ = shift;
    for my $defent (@{$obj->{Define}}) {
	my($name, $re, $string) = @$defent;
	s/$re/$string/g;
    }
    s{ (\$ENV\{ (['"]?) \w+ \g{-1} \}) }{ eval($1) // $1 }xge;
}

sub mode {
    my $obj = shift;
    @_ == 1 and return $obj->{Mode}->{uc shift};
    die "Unexpected parameter." if @_ % 2;
    pairmap {
	$obj->{Mode}->{uc $a} = $b;
    } @_;
}

use constant BUILTIN => "__BUILTIN__";
sub validopt { $_[0] ne BUILTIN }

sub setlocal {
    my $obj = shift;
    $obj->setlist("Expand", @_);
}

sub setopt {
    my $obj = shift;
    $obj->setlist("Option", @_);
}

sub setlist {
    my $obj = shift;
    my $list = $obj->{+shift};
    my $name = shift;
    my @args = do {
	if (ref $_[0] eq 'ARRAY') {
	    @{ $_[0] };
	} else {
	    map { shellwords $_ } @_;
	}
    };

    for (my $i = 0; $i < @args; $i++) {
	if (my @opt = $obj->getlocal($args[$i])) {
	    splice @args, $i, 1, @opt;
	    redo;
	}
    }

    for (@args) {
	$obj->expand(\$_);
    }
    unshift @$list, [ $name, @args ];
}

sub getopt {
    my $obj = shift;
    my($name, %opt) = @_;
    return () if $name eq 'default' and not $opt{DEFAULT} || $opt{ALL};

    my $list = $obj->{Option};
    my $e = first {
	$_->[0] eq $name and $opt{ALL} || validopt($_->[1])
    } @$list;
    my @e = $e ? @$e : ();
    shift @e;

    # check autoload
    unless (@e) {
	my $hash = $obj->{Autoload};
	for my $mod (@{$obj->{Automod}}) {
	    if (exists $hash->{$mod}->{$name}) {
		delete $hash->{$mod};
		return ($mod, $name);
	    }
	}
    }

    @e;
}

sub getlocal {
    my $obj = shift;
    my($name, %opt) = @_;

    my $e = first { $_->[0] eq $name } @{$obj->{Expand}};
    my @e = $e ? @$e : ();
    shift @e;
    @e;
}

sub expand_args {
    my $obj = shift;
    my @args = @_;

    ##
    ## Expand `&function' style arguments.
    ##
    if ($obj->mode('function')) {
	@args = map {
	    if (/^&(.+)/) {
		my $func = parse_func $obj->module . "::$1";
		$func ? $func->call : $_;
	    } else {
		$_;
	    }
	}
	@args;
    }

    ##
    ## Expand wildcards.
    ##
    if ($obj->mode('wildcard')) {
	@args = map {
	    my @glob = glob $_;
	    @glob ? @glob : $_;
	} @args;
    }

    @args;
}

sub default {
    my $obj = shift;
    $obj->getopt('default', DEFAULT => 1);
}

sub options {
    my $obj = shift;
    my $opt = $obj->{Option};
    my $automod = $obj->{Automod};
    my $auto = $obj->{Autoload};
    my @opt = reverse map { $_->[0] } @$opt;
    my @auto = map { sort keys %{$auto->{$_}} } @$automod;
    (@opt, @auto);
}

sub help {
    my $obj = shift;
    my $name = shift;
    my $list = $obj->{Help};
    if (@_) {
	unshift(@$list, [ $name, shift ]);
    } else {
	my $e = first { $_->[0] eq $name } @$list;
	$e ? $e->[1] : undef;
    }
}

sub parsetext {
    my $obj = shift;
    my $text = shift;
    my $re = qr{
	(?|
	    # HERE document
	    (.+\s) << (?<mark>\w+) \n
	    (?<here> (?s:.*?) \n )
	    \g{mark}\n
	|
	    (.+)\n?
	)
    }x;
    while ($text =~ m/$re/g) {
	my $line = do {
	    if (defined $+{here}) {
		$1 . $+{here};
	    } else {
		$1;
	    }
	};
	$obj->parseline($line);
    }
    $obj;
}

sub parseline {
    my $obj = shift;
    my $line = shift;
    my @arg = split ' ', $line, 3;

    my %min_args = ( mode => 1, DEFAULT => 3 );
    my $min_args = $min_args{$arg[0]} || $min_args{DEFAULT};
    if (@arg < $min_args) {
	warn sprintf("Parse error in %s: %s\n", $obj->title, $line);
	return;
    }

    ##
    ## in-line help document after //
    ##
    my $optname = $arg[1] // '';
    if ($arg[0] eq "builtin") {
	for ($optname) {
	    s/[^\w\-].*//; # remove alternative names after `|'.
	    s/^(?=([\w\-]+))/length($1) == 1 ? '-' : '--'/e;
	}
    }
    if ($arg[2] and $arg[2] =~ s{ (?:^|\s+) // \s+ (?<message>.*) }{}x) {
	$obj->help($optname, $+{message});
    }

    ##
    ## Commands
    ##
    if ($arg[0] eq "define") {
	$obj->define($arg[1], $arg[2]);
    }
    elsif ($arg[0] eq "option") {
	$obj->setopt($arg[1], $arg[2]);
    }
    elsif ($arg[0] eq "expand") {
	$obj->setlocal($arg[1], $arg[2]);
    }
    elsif ($arg[0] eq "defopt") {
	$obj->define($arg[1], $arg[2]);
	$obj->setopt($arg[1], $arg[1]);
    }
    elsif ($arg[0] eq "builtin") {
	$obj->setopt($optname, BUILTIN);
	if ($arg[2] =~ /^\\?(?<mark>[\$\@\%\&])(?<name>[\w:]+)/) {
	    my($mark, $name) = @+{"mark", "name"};
	    my $mod = $obj->module;
	    /:/ or s/^/$mod\::/ for $name;
	    no strict 'refs';
	    $obj->builtin($arg[1] => {'$' => \${$name},
				      '@' => \@{$name},
				      '%' => \%{$name},
				      '&' => \&{$name}}->{$mark});
	}
    }
    elsif ($arg[0] eq "autoload") {
	shift @arg;
	$obj->autoload(@arg);
    }
    elsif ($arg[0] eq "mode") {
	shift @arg;
	for (@arg) {
	    if (/^(no-?)?(.*)/i) {
		$obj->mode($2 => $1 ? 0 : 1);
	    }
	}
    }
    elsif ($arg[0] eq "help") {
	$obj->help($arg[1], $arg[2]);
    }
    else {
	warn sprintf("Unknown operator \"%s\" in %s\n",
		     $arg[0], $obj->title);
    }

    $obj;
}

sub builtin {
    my $obj = shift;
    my $list = $obj->{Builtin};
    @_  ? push @$list, @_
	: @$list;
}

sub autoload {
    my $obj = shift;
    my $module = shift;
    my @option = map { split ' ' } @_;

    my $hash = ($obj->{Autoload}->{$module} //= {});
    my $list = $obj->{Automod};
    for (@option) {
	$hash->{$_} = 1;
	$obj->help($_, "autoload: $module");
    }
    push @$list, $module if not grep { $_ eq $module } @$list;
}

sub call {
    my $obj = shift;
    my $list = $obj->{Call};
    @_  ? push @$list, @_
	: @$list;
}

sub call_if_defined {
    my($module, $name, @param) = @_;
    my $func = "$module\::$name";
    if (defined &$func) {
	no strict 'refs';
	$func->(@param);
    }
}

sub run_inits {
    my $obj = shift;
    my $argv = shift;
    my $module = $obj->module;
    local @ARGV = ();

    call_if_defined $module, "initialize" => ($obj, $argv);

    for my $call ($obj->call) {
	my $func = $call->can('call') ? $call : parse_func($call);
	$func->call;
    }

    call_if_defined $module, "finalize" => ($obj, $argv);
}

1;

=head1 NAME

Getopt::EX::Module - RC/Module data container

=head1 SYNOPSIS

  use Getopt::EX::Module;

  my $bucket = Getopt::EX::Module->new(
	BASECLASS => $baseclass,
	FILE => $file_name  /  MODULE => $module_name,
	);

=head1 DESCRIPTION

This module is usually used from L<Getopt::EX::Loader>, and keeps
all data about the loaded rc file or module.

=head2 MODULE

After a user-defined module is loaded, the subroutine C<initialize> is
called if it exists in the module.  At this time, the container object is
passed to the function as the first argument and the following command
argument pointer as the second.  So you can use it to directly access
the object contents through the class interface.

Following C<initialize>, the function defined with the module option is called.

Finally, the subroutine C<finalize> is called if defined, to finalize the startup
process of the module.

=head2 FILE

For rc files, the section after the C<__PERL__> or C<__PERL5__> mark is
executed as a Perl program.  At this time, the module object is assigned to the
variable C<$MODULE>, and you can access the module API through it.

    if (our $MODULE) {
        $MODULE->setopt('default', '--number');
    }

=head1 RC FILE FORMAT

=over 7

=item B<option> I<name> I<string>

Define option I<name>.  Argument I<string> is processed by the
I<shellwords> routine defined in the L<Text::ParseWords> module.  Be aware
that this module sometimes requires escaped backslashes.

Any kind of string can be used for an option name but it is not combined
with other options.

    option --fromcode --outside='(?s)\/\*.*?\*\/'
    option --fromcomment --inside='(?s)\/\*.*?\*\/'

If the option named B<default> is defined, it will be used as a
default option.

For the purpose of including following arguments within replaced
strings, two special notations can be used in option definitions.

The string C<< $<n> >> is replaced by the I<n>th argument after the
substituted option, where I<n> is a number starting from one.  Because C<<
$<0> >> is replaced by the defined option itself, you have to be careful
about infinite loops.

The string C<< $<shift> >> is replaced by the following command line argument
and the argument is removed from the list.

For example, when

    option --line --le &line=$<shift>

is defined, the command

    greple --line 10,20-30,40

will be evaluated as:

    greple --le &line=10,20-30,40

There are special arguments to manipulate option behavior and the rest
of the arguments.  Argument C<< $<move> >> moves all following arguments
there, C<< $<remove> >> just removes them, and C<< $<copy> >> copies
them.  These do not work when included as part of a string.

They take one or two optional parameters, which are passed to the Perl
C<splice> function as I<offset> and I<length>.  C<< $<move(0,1)> >> is the
same as C<< $<shift> >>; C<< $<copy(0,1)> >> is the same as C<< $<1> >>;
C<< $<move> >> is the same as C<< $<move(0)> >>; C<< $<move(-1)> >> moves
the last argument; C<< $move(1,1) >> moves the second argument.  The next
example exchanges the following two arguments.

    option --exch $<move(1,1)>

You can use the recently introduced C<< $<ignore> >> to ignore the
argument.  Some existing modules use C<< $<move(0,0)> >> for the same
purpose, because it effectively does nothing.

    option --deprecated $<ignore>
    option --deprecated $<move(0,0)>

=item B<expand> I<name> I<string>

Define local option I<name>.  The B<expand> command is almost the same as the
B<option> command in terms of its function.  However, options defined
by this command are expanded in, and only in, the process of
definition, while option definitions are expanded when command arguments
are processed.

This is similar to a string macro defined by the following B<define>
command.  But macro expansion is done by simple string replacement, so
you have to use B<expand> to define options composed of multiple
arguments.

=item B<define> I<name> I<string>

Define a string macro.  This is similar to B<option>, but the argument is
not processed by I<shellwords> and is treated as simple text, so
meta-characters can be included without escaping.  Macro expansion is
performed for option definitions and other macro definitions.  Macros are not
evaluated in command line options.  Use the option directive if you want to
use it in the command line,

    define (#kana) \p{InKatakana}
    option --kanalist --nocolor -o --join --re '(#kana)+(\n(#kana)+)*'
    help   --kanalist List up Katakana string

A here-document can be used to define strings including newlines.

    define __script__ <<EOS
    {
    	...
    }  
    EOS

The special macro C<__PACKAGE__> is pre-defined to the module name.

=item B<help> I<name>

Define a help message for option I<name>.

=item B<builtin> I<spec> I<variable>

Define a built-in option which should be processed by the option parser.
The defined option spec can be retrieved by the B<builtin> method, and the script is
responsible for passing them to the parser.

Arguments are assumed to be L<Getopt::Long> style specs, and
I<variable> is a string starting with C<$>, C<@> or C<%>.  They will be
replaced by a reference to the object which the string represents.

=item B<autoload> I<module> I<options>

Define a module which should be loaded automatically when the specified
option is found in the command arguments.

For example,

    autoload -Mdig --dig

replaces the option "I<--dig>" with "I<-Mdig --dig>", and the I<dig> module is
loaded before processing the I<--dig> option.

=item B<mode> [I<no>]I<name>

Set or unset mode I<name>.  Currently, B<function> and B<wildcard> can
be used as a name.  See the METHODS section.

The next example is used in the L<App::Greple::subst::dyncmap> module to
produce parameters on the fly.

    mode function
    option --dyncmap &dyncmap($<shift>)

=back

=head1 METHODS

=over 4

=item B<new> I<configure option>

Create an object.  Parameters are passed to the C<configure> method.

=item B<configure>

Configure the object.  Parameters are passed in hash name and value style.

=over 4

=item B<BASECLASS> =E<gt> I<class>

Set base class.

=item B<FILE> =E<gt> I<filename>

Load file.

=item B<MODULE> =E<gt> I<modulename>

Load module.

=back

=item B<define> I<name>, I<macro>

Define macro.

=item B<setopt> I<name>, I<option>

Set option.

=item B<setlocal> I<name>, I<option>

Set option which is effective only in the module.

=item B<getopt> I<name>

Get an option.  Takes an option name and returns its definition if
available.  It doesn't return the I<default> option; get it by the I<default>
method.

=item B<default>

Get the default option.  Use C<setopt(default =E<gt> ...)> to set it.

=item B<builtin>

Get built-in options.

=item B<autoload>

Set autoload module.

=item B<mode>

Set the argument treatment mode.  Arguments produced by option expansion
will be the subject of post-processing.  This method defines the behavior
of it.

=over 4

=item B<mode>(B<function> => 1)

Interpret arguments starting with '&' as a function, and replace them with
the result of the function call.

=item B<mode>(B<wildcard> => 1)

Replace wildcard arguments with matched file names.

=back

=back
