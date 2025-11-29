package Getopt::EX::Func;

our $VERSION = "3.00";

use v5.14;
use warnings;
use Carp;

use Exporter 'import';
our @EXPORT      = qw();
our @EXPORT_OK   = qw(parse_func callable arg2kvlist);
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use Data::Dumper;

use Scalar::Util qw(blessed);
sub callable {
    my $target = shift;
    blessed $target and $target->can('call');
}

sub new {
    my $class = shift;
    my $obj = bless [ @_ ], $class;
}

sub append {
    my $obj = shift;
    push @$obj, @_;
}

sub call {
    my $obj = shift;
    unshift @_, @$obj;
    my $name = shift;

    no strict 'refs';
    goto &$name;
}

##
## Create a closure that calls the named function with preset arguments.
## Used internally when parse_func is called with the 'pointer' option.
## The 'package main' may be unnecessary since $name is fully qualified,
## but is kept for safety in case of future changes.
##
sub closure {
    my $name = shift;
    my @argv = @_;
    sub {
	package main;
	no strict 'refs';
	unshift @_, @argv;
	goto &$name;
    }
}

##
## sub { ... }
## funcname(arg1,arg2,arg3=val3)
## funcname=arg1,arg2,arg3=val3
##

##
## Regex to match balanced parentheses, including nested ones.
## Uses recursive subpattern (?-1) to match inner parentheses.
## Possessive quantifiers (++ and *+) prevent backtracking for efficiency.
##
my $paren_re = qr/( \( (?: [^()]++ | (?-1) )*+ \) )/x;

sub parse_func {
    my $opt = ref $_[0] eq 'HASH' ? shift : {};
    local $_ = shift;
    my $noinline = $opt->{noinline};
    my $pointer = $opt->{pointer};
    my $caller = caller;
    my $pkg = $opt->{PACKAGE} || $caller;

    my @func;

    if (not $noinline and /^sub\s*{/) {
	my $sub = eval "package $pkg; $_";
	if ($@) {
	    warn "Error in function -- $_ --.\n";
	    die $@;
	}
	croak "Unexpected result from eval.\n" if ref $sub ne 'CODE';
	@func = ($sub);
    }
    elsif (m{^ &? (?<name> [\w:]+ ) (?<arg> $paren_re | =.* )? $}x) {
	my $name = $+{name};
	my $arg = $+{arg} // '';
	$arg =~ s/^ (?| \( (.*) \) | = (.*) ) $/$1/x;
	$name =~ s/^/$pkg\::/ unless $name =~ /::/;
	@func = ($name, arg2kvlist($arg));
    }
    else {
	return undef;
    }

    __PACKAGE__->new( $pointer ? closure(@func) : @func );
}

##
## convert "key1,key2,key3=val3" to (key1=>1, key2=>1, key3=>"val3")
## use ~ instead of = to take the rest of the string as a value
## e.g., "key1,key2~a,b,c" => (key1=>1, key2=>"a,b,c")
##
sub arg2kvlist {
    my @kv;
    for (@_) {
	while (/\G \s*
	       (?<k> [\w\-.]+ )
	       (?:
		   ~ (?<rest> .* )
		 |
		   (?: = (?<v> (?: [^,()]++ | ${paren_re} )*+ ) )?
	       )
	       ,*/xgc
	    ) {
	    if (defined $+{rest}) {
		push @kv, ( $+{k}, $+{rest} );
		last;
	    } else {
		push @kv, ( $+{k}, $+{v} // 1 );
	    }
	}
	my $pos = pos() // 0;
	if ($pos != length) {
	    die "parse error in \"$_\".\n";
	}
    }
    @kv;
}

1;

=head1 NAME

Getopt::EX::Func - Function call interface


=head1 SYNOPSIS

  use Getopt::EX::Func qw(parse_func);

  my $func = parse_func("func_name(key=value,flag)");

  $func->call;

=head1 DESCRIPTION

This module provides a way to create function call objects used in the
L<Getopt::EX> module set.

For example, suppose your script has a B<--begin> option that
specifies a function to call at the beginning of execution.  You can
implement it like this:

    use Getopt::EX::Func qw(parse_func);

    GetOptions("begin:s" => \$opt_begin);

    my $func = parse_func($opt_begin);

    $func->call;

The user can then invoke the script as:

    % example -Mfoo --begin 'repeat(debug,msg=hello,count=2)'

The function C<repeat> should be declared in module C<foo> or in a
startup rc file such as F<~/.examplerc>.  It can be implemented like
this:

    our @EXPORT = qw(repeat);
    sub repeat {
        my %opt = @_;
        print Dumper \%opt if $opt{debug};
        say $opt{msg} for 1 .. $opt{count};
    }

=head1 FUNCTION SPEC

The C<parse_func> function accepts the following string formats.

A function name can optionally be prefixed with C<&>, and parameters
can be specified in two equivalent forms using parentheses or C<=>:

    func(key=value,key2=value2)
    func=key=value,key2=value2
    &func(key=value)

So the following two commands are equivalent:

    % example --begin 'repeat(debug,msg=hello,count=2)'
    % example --begin 'repeat=debug,msg=hello,count=2'

Both will call the function as:

    repeat( debug => 1, msg => 'hello', count => '2' );

Arguments are passed as I<key> =E<gt> I<value> pairs.  Parameters
without a value (C<debug> in this example) are assigned the value 1.
Key names may contain word characters (alphanumeric and underscore),
hyphens, and dots.

Commas normally separate parameters.  If a value needs to contain
commas, there are two ways to handle this:

=over 4

=item Parentheses

Commas inside parentheses are preserved:

    func(pattern=(a,b,c),debug)

This calls:

    func( pattern => '(a,b,c)', debug => 1 );

Note that the parentheses are included in the value.

=item Tilde

Use C<~> instead of C<=> to capture the entire remaining string as
the value:

    func(debug,pattern~a,b,c)

This calls:

    func( debug => 1, pattern => 'a,b,c' );

Since C<~> consumes the rest of the string, no parameters can follow
it.

=back

An anonymous subroutine can also be specified inline:

    % example --begin 'sub{ say "wahoo!!" }'

The function is evaluated under C<use v5.14>, so features like C<say>
are available.
