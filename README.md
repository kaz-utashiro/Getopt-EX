[![Actions Status](https://github.com/kaz-utashiro/Getopt-EX/workflows/test/badge.svg)](https://github.com/kaz-utashiro/Getopt-EX/actions) [![MetaCPAN Release](https://badge.fury.io/pl/Getopt-EX.svg)](https://metacpan.org/release/Getopt-EX)
# NAME

Getopt::EX - Getopt Extender

# VERSION

Version 2.2.2

# DESCRIPTION

[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) extends basic function of [Getopt](https://metacpan.org/pod/Getopt) family to support
user-definable option aliases, and dynamic module which works together
with a script through option interface.

# INTERFACES

There are two major interfaces to use [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) modules.

Easy one is [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) compatible module, [Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong).
You can simply replace module declaration and get the benefit of this
module to some extent.  It allows user to make start up _rc_ file in
their home directory, which provide user-defined option aliases.

Use [Getopt::EX::Loader](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALoader) to get full capabilities.  Then the user of
your script can make their own extension module which work together
with original command through command option interface.

Another module [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap) is made to produce colored text
on ANSI terminal, and to provide easy way to maintain labeled colormap
table and option handling.

## [Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong)

This is the easiest way to get started with [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX).  This
module is almost compatible with [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) and drop-in
replaceable.

In addition, if the command name is _example_,

    ~/.examplerc

file is loaded by default.  In this rc file, user can define their own
option with macro processing.  This is useful when the command takes
complicated arguments.  User can also define default option which is
used always.  For example,

    option default -n

gives option _-n_ always when the script executed.  See
[Getopt::EX::Module](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AModule) document what you can do in this file.

If the rc file includes a section start with `__PERL__`, it is
evaluated as a perl program.  User can define any kind of functions
there, which can be invoked from command line option if the script is
aware of them.  At this time, module object is assigned to variable
`$MODULE`, and you can access module API through it.

Also, special command option preceded by **-M** is taken and
corresponding perl module is loaded.  For example,

    % example -Mfoo

will load `App::example::foo` module.

This module is normal perl module, so user can write anything they
want.  If the module option come with initial function call, it is
called at the beginning of command execution.  Suppose that the module
_foo_ is specified like this:

    % example -Mfoo::bar(buz=100) ...

Then, after the module **foo** is loaded, function _bar_ is called
with the parameter _buz_ with value 100.

If the module includes `__DATA__` section, it is interpreted just
same as rc file.  So you can define arbitrary option there.  Combined
with startup function call described above, it is possible to control
module behavior by user defined option.

## [Getopt::EX::Loader](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALoader)

This module provides more primitive access to the underlying modules.
You should create loader object first:

    use Getopt::EX::Loader;
    my $loader = Getopt::EX::Loader->new(
        BASECLASS => 'App::example',
        );

Then load rc file:

    $loader->load_file("$ENV{HOME}/.examplerc");

And process command line options:

    $loader->deal_with(\@ARGV);

Finally gives built-in function declared in dynamically loaded modules
to option parser.

    my $parser = Getopt::Long::Parser->new;
    $parser->getoptions( ... , $loader->builtins )

Actually, this is what [Getopt::EX::Long](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALong) module is doing
internally.

## [Getopt::EX::Func](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AFunc)

To make your script to communicate with user-defined subroutines, use
[Getopt::EX::Func](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AFunc) module, which provide `parse_func` interface.  If
your script has **--begin** option which tells the script to call
specific function at the beginning of execution.  Write something
like:

    use Getopt::EX::Func qw(parse_func);
    GetOptions("begin:s" => \my $opt_begin);
    my $func = parse_func($opt_begin);
    $func->call;

Then the script can be invoked like this:

    % example -Mfoo --begin 'repeat(debug,msg=hello,count=2)'

See [Getopt::EX::Func](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AFunc) for more detail.

## [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap)

This module is not so tightly coupled with other modules in
[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX).  It provides concise way to specify ANSI terminal
colors with various effects, and produce terminal sequences by color
specification or label parameter.

You can use this module with normal [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong):

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

and then get colored string as follows.

    print $handler->color("FILE", "FILE in Red\n");
    print $handler->color("LINE", "LINE in Blue\n");
    print $handler->color("TEXT", "TEXT in Green\n");

In this example, user can change these colors from command line option
like this:

    % example --colormap FILE=C,LINE=M,TEXT=Y

or call arbitrary perl function like:

    % example --colormap FILE='sub{uc}'

Above example produces uppercase version of provided string instead of
ANSI color sequence.

If you want to use just coloring function, use backend module
[Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise).

## [Getopt::EX::LabeledParam](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALabeledParam)

This is super-class of [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap).  [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)
support parameter handling within hash,

    my %defines;
    GetOptions ("define=s" => \%defines);

and the parameter can be given in `key=value` format.

    --define os=linux --define vendor=redhat

Using [Getopt::EX::LabeledParam](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALabeledParam), this can be written as:

    my @defines;
    my %defines;
    GetOptions ("defines=s" => \@defines);
    Getopt::EX::LabeledParam
        ->new(HASH => \%defines)
        ->load_params (@defines);

and the parameter can be given mixed together.

    --define os=linux,vendor=redhat

## [Getopt::EX::Numbers](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ANumbers)

Parse number parameter description and produces number range list or
number sequence.  Number format is composed by four elements: `start`,
`end`, `step` and `length`, like this:

    1           1
    1:3         1,2,3
    1:20:5      1,     6,     11,       16
    1:20:5:3    1,2,3, 6,7,8, 11,12,13, 16,17,18

# SEE ALSO

## [Term::ANSIColor::Concise](https://metacpan.org/pod/Term%3A%3AANSIColor%3A%3AConcise)

Coloring capability of [Getopt::EX::Colormap](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AColormap) is now implemented in
this module.

## [Getopt::EX::Hashed](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AHashed)

[Getopt::EX::Hashed](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AHashed) is a module to automate a hash object to store
command line option values for [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) and compatible modules
including **Getopt::EX::Long**.

## [Getopt::EX::Config](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AConfig)

[Getopt::EX::Config](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AConfig) provides an interface to define configuration
information for `Getopt::EX` modules.  Using this module, it is
possible to define configuration information only for the module and
to define module-specific command options.

## [Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n)

[Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n) provides an easy way to set locale environment
before executing command.

## [Getopt::EX::termcolor](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Atermcolor)

[Getopt::EX::termcolor](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Atermcolor) is a common module to manipulate system
dependent terminal color.

## [Getopt::EX::RPN](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ARPN)

[Getopt::EX::RPN](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ARPN) provides a RPN (Reverse Polish Notation)
calculation interface for command line arguments.  This is convenient
when you want to define parameter based on terminal height or width.

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
