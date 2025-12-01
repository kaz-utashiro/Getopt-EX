[![Actions Status](https://github.com/kaz-utashiro/Getopt-EX/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/kaz-utashiro/Getopt-EX/actions?workflow=test) [![MetaCPAN Release](https://badge.fury.io/pl/Getopt-EX.svg)](https://metacpan.org/release/Getopt-EX)
# NAME

Getopt::EX - Getopt Extender

# VERSION

Version 3.01

# DESCRIPTION

[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) extends the basic functionality of [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) to
support user-definable option aliases and dynamic extension modules
that integrate with scripts through the option interface.

# INTERFACES

There are two major interfaces for using [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) modules.

The simpler one is the [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)-compatible module,
[Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong).  You can simply replace the module declaration to
get the benefits of this module.  It allows users to create a startup
_rc_ file in their home directory to define option aliases.

For full capabilities, use [Getopt::EX::Loader](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALoader).  This allows users
of your script to create their own extension modules that work
together with the original command through the option interface.

Another module, [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap), is designed to produce
colored text on ANSI terminals and provides an easy way to maintain
labeled colormap tables with option handling.

## [Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong)

This is the easiest way to get started with [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX).  This
module is almost fully compatible with [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) and can be used
as a drop-in replacement.

If the command name is _example_, the file

    ~/.examplerc

is loaded by default.  In this rc file, users can define their own
option aliases with macro processing.  This is useful when a command
takes complex arguments.  Users can also define default options that
are always applied.  For example:

    option default -n

ensures that the _-n_ option is always used when the script runs.
See [Getopt::EX::Module](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AModule) for full details on rc file format.

If the rc file includes a section starting with `__PERL__` or
`__PERL5__`, it is evaluated as Perl code.  Users can define
functions there, which can be invoked from command line options if the
script supports them.  The module object is available through the
`$MODULE` variable.

Special command options starting with **-M** load the corresponding
Perl module.  For example:

    % example -Mfoo

loads the `App::example::foo` module.

Since extension modules are normal Perl modules, users can write any
code they need.  If the module option includes an initial function
call, that function is called when the module is loaded.  For example:

    % example -Mfoo::bar(buz=100)

loads module **foo** and calls function _bar_ with the parameter
_buz_ set to 100.  The `=` form is also supported:

    % example -Mfoo::bar=buz=100

If the module includes a `__DATA__` section, it is interpreted as an
rc file.  Combined with the startup function call, this allows module
behavior to be controlled through user-defined options.

## [Getopt::EX::Loader](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALoader)

This module provides lower-level access to the underlying
functionality.  First create a loader object:

    use Getopt::EX::Loader;
    my $loader = Getopt::EX::Loader->new(
        BASECLASS => 'App::example',
    );

Then load the rc file:

    $loader->load_file("$ENV{HOME}/.examplerc");

Process command line options:

    $loader->deal_with(\@ARGV);

Finally, pass the built-in options declared in dynamically loaded
modules to the option parser:

    my $parser = Getopt::Long::Parser->new;
    $parser->getoptions( ... , $loader->builtins );

This is essentially what [Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong) does internally.

## [Getopt::EX::Func](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AFunc)

This module provides the `parse_func` interface for communicating
with user-defined subroutines.  If your script has a **--begin** option
that specifies a function to call at the beginning of execution:

    use Getopt::EX::Func qw(parse_func);
    GetOptions("begin:s" => \my $opt_begin);
    my $func = parse_func($opt_begin);
    $func->call;

The user can then invoke the script like this:

    % example -Mfoo --begin 'repeat(debug,msg=hello,count=2)'

To include commas in parameter values, use `*=` to take the rest of
the string, or `/=` with a delimiter:

    func(pattern*=a,b,c)
    func(pattern/=|a,b,c|)

Both pass `a,b,c` as the value of `pattern`.  The `/=` form allows
multiple parameters with commas:

    func(pat1/=|a,b|,pat2/=|c,d|)

See [Getopt::EX::Func](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AFunc) for more details.

## [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap)

This module is not tightly coupled with other [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) modules.
It provides a concise way to specify ANSI terminal colors with various
effects, producing terminal escape sequences from color specifications
or label parameters.

You can use this module with standard [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong):

    my @opt_colormap;
    use Getopt::Long;
    GetOptions("colormap|cm=s" => \@opt_colormap);

    my %colormap = ( # default color map
        FILE => 'R',
        LINE => 'G',
        TEXT => 'B',
    );
    my @colors;

    require Getopt::EX::Colormap;
    my $handler = Getopt::EX::Colormap->new(
        HASH => \%colormap,
        LIST => \@colors,
    );

    $handler->load_params(@opt_colormap);

Then get colored strings:

    print $handler->color("FILE", "FILE in Red\n");
    print $handler->color("LINE", "LINE in Green\n");
    print $handler->color("TEXT", "TEXT in Blue\n");

Users can change these colors from the command line:

    % example --colormap FILE=C,LINE=M,TEXT=Y

or call an arbitrary Perl function:

    % example --colormap FILE='sub{uc}'

The above produces an uppercase version of the string instead of a
color sequence.

For just the coloring functionality, use the backend module
[Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise).

## [Getopt::EX::LabeledParam](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALabeledParam)

This is the superclass of [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap).  [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)
supports parameter handling with a hash:

    my %defines;
    GetOptions("define=s" => \%defines);

Parameters can be given in `key=value` format:

    --define os=linux --define vendor=redhat

Using [Getopt::EX::LabeledParam](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALabeledParam), this can be written as:

    my @defines;
    my %defines;
    GetOptions("define=s" => \@defines);
    Getopt::EX::LabeledParam
        ->new(HASH => \%defines)
        ->load_params(@defines);

allowing parameters to be combined:

    --define os=linux,vendor=redhat

## [Getopt::EX::Numbers](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ANumbers)

Parses number parameter descriptions and produces number range lists
or sequences.  The format consists of four elements: `start`,
`end`, `step`, and `length`:

    1           1
    1:3         1,2,3
    1:20:5      1,     6,     11,       16
    1:20:5:3    1,2,3, 6,7,8, 11,12,13, 16,17,18

# SEE ALSO

- [Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise)

    The coloring capability of [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap) is implemented in
    this module.

- [Getopt::EX::Hashed](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AHashed)

    Automates a hash object to store command line option values for
    [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) and compatible modules including [Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong).

- [Getopt::EX::Config](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AConfig)

    Provides an interface to define configuration information for
    [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) modules, including module-specific options.

- [Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n)

    Provides an easy way to set the locale environment before executing a
    command.

- [Getopt::EX::termcolor](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Atermcolor)

    A common module to handle system-dependent terminal colors.

- [Getopt::EX::RPN](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ARPN)

    Provides an RPN (Reverse Polish Notation) calculation interface for
    command line arguments, useful for defining parameters based on
    terminal dimensions.

# AUTHOR

Kazumasa Utashiro

# COPYRIGHT

The following copyright notice applies to all the files provided in
this distribution, including binary files, unless explicitly noted
otherwise.

Copyright 2015-2025 Kazumasa Utashiro

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
