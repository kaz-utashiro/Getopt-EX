package Getopt::EX;
use 5.014;

our $VERSION = "3.03";

1;

=head1 NAME

Getopt::EX - Getopt Extender


=head1 VERSION

Version 3.03


=head1 DESCRIPTION

L<Getopt::EX> extends the basic functionality of L<Getopt::Long> to
support user-definable option aliases and dynamic extension modules
that integrate with scripts through the option interface.

=head1 INTERFACES

There are two major interfaces for using L<Getopt::EX> modules.

The simpler one is the L<Getopt::Long>-compatible module,
L<Getopt::EX::Long>.  You can simply replace the module declaration to
get the benefits of this module.  It allows users to create a startup
I<rc> file in their home directory to define option aliases.

For full capabilities, use L<Getopt::EX::Loader>.  This allows users
of your script to create their own extension modules that work
together with the original command through the option interface.

Another module, L<Getopt::EX::Colormap>, is designed to produce
colored text on ANSI terminals and provides an easy way to maintain
labeled colormap tables with option handling.

=head2 L<Getopt::EX::Long>

This is the easiest way to get started with L<Getopt::EX>.  This
module is almost fully compatible with L<Getopt::Long> and can be used
as a drop-in replacement.

If the command name is I<example>, the file

    ~/.examplerc

is loaded by default.  In this rc file, users can define their own
option aliases with macro processing.  This is useful when a command
takes complex arguments.  Users can also define default options that
are always applied.  For example:

    option default -n

ensures that the I<-n> option is always used when the script runs.
See L<Getopt::EX::Module> for full details on rc file format.

If the rc file includes a section starting with C<__PERL__> or
C<__PERL5__>, it is evaluated as Perl code.  Users can define
functions there, which can be invoked from command line options if the
script supports them.  The module object is available through the
C<$MODULE> variable.

Special command options starting with B<-M> load the corresponding
Perl module.  For example:

    % example -Mfoo

loads the C<App::example::foo> module.

Since extension modules are normal Perl modules, users can write any
code they need.  If the module option includes an initial function
call, that function is called when the module is loaded.  For example:

    % example -Mfoo::bar(buz=100)

loads module B<foo> and calls function I<bar> with the parameter
I<buz> set to 100.  The C<=> form is also supported:

    % example -Mfoo::bar=buz=100

If the module includes a C<__DATA__> section, it is interpreted as an
rc file.  Combined with the startup function call, this allows module
behavior to be controlled through user-defined options.

=head2 L<Getopt::EX::Loader>

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

This is essentially what L<Getopt::EX::Long> does internally.

=head2 L<Getopt::EX::Func>

This module provides the C<parse_func> interface for communicating
with user-defined subroutines.  If your script has a B<--begin> option
that specifies a function to call at the beginning of execution:

    use Getopt::EX::Func qw(parse_func);
    GetOptions("begin:s" => \my $opt_begin);
    my $func = parse_func($opt_begin);
    $func->call;

The user can then invoke the script like this:

    % example -Mfoo --begin 'repeat(debug,msg=hello,count=2)'

To include commas in parameter values, use C<*=> to take the rest of
the string, or C</=> with a delimiter:

    func(pattern*=a,b,c)
    func(pattern/=|a,b,c|)

Both pass C<a,b,c> as the value of C<pattern>.  The C</=> form allows
multiple parameters with commas:

    func(pat1/=|a,b|,pat2/=|c,d|)

See L<Getopt::EX::Func> for more details.

=head2 L<Getopt::EX::Colormap>

This module is not tightly coupled with other L<Getopt::EX> modules.
It provides a concise way to specify ANSI terminal colors with various
effects, producing terminal escape sequences from color specifications
or label parameters.

You can use this module with standard L<Getopt::Long>:

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
L<Term::ANSIColor::Concise>.

=head2 L<Getopt::EX::LabeledParam>

This is the superclass of L<Getopt::EX::Colormap>.  L<Getopt::Long>
supports parameter handling with a hash:

    my %defines;
    GetOptions("define=s" => \%defines);

Parameters can be given in C<key=value> format:

    --define os=linux --define vendor=redhat

Using L<Getopt::EX::LabeledParam>, this can be written as:

    my @defines;
    my %defines;
    GetOptions("define=s" => \@defines);
    Getopt::EX::LabeledParam
        ->new(HASH => \%defines)
        ->load_params(@defines);

allowing parameters to be combined:

    --define os=linux,vendor=redhat

=head2 L<Getopt::EX::Numbers>

Parses number parameter descriptions and produces number range lists
or sequences.  The format consists of four elements: C<start>,
C<end>, C<step>, and C<length>:

    1           1
    1:3         1,2,3
    1:20:5      1,     6,     11,       16
    1:20:5:3    1,2,3, 6,7,8, 11,12,13, 16,17,18

=head1 SEE ALSO

=over 4

=item L<Term::ANSIColor::Concise>

The coloring capability of L<Getopt::EX::Colormap> is implemented in
this module.

=item L<Getopt::EX::Hashed>

Automates a hash object to store command line option values for
L<Getopt::Long> and compatible modules including L<Getopt::EX::Long>.

=item L<Getopt::EX::Config>

Provides an interface to define configuration information for
L<Getopt::EX> modules, including module-specific options.

=item L<Getopt::EX::i18n>

Provides an easy way to set the locale environment before executing a
command.

=item L<Getopt::EX::termcolor>

A common module to handle system-dependent terminal colors.

=item L<Getopt::EX::RPN>

Provides an RPN (Reverse Polish Notation) calculation interface for
command line arguments, useful for defining parameters based on
terminal dimensions.

=back

=head1 AUTHOR

Kazumasa Utashiro

=head1 COPYRIGHT

The following copyright notice applies to all the files provided in
this distribution, including binary files, unless explicitly noted
otherwise.

Copyright 2015-2025 Kazumasa Utashiro

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#  LocalWords:  Getopt colormap perl foo bar buz colorize BASECLASS
#  LocalWords:  rc examplerc ENV ARGV getoptions builtins func linux
#  LocalWords:  GetOptions redhat Kazumasa Utashiro RPN
