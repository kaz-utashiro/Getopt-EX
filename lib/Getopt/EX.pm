package Getopt::EX;
use 5.014;

our $VERSION = "2.3.1";

1;

=head1 NAME

Getopt::EX - Getopt Extender


=head1 VERSION

Version 2.3.1


=head1 DESCRIPTION

L<Getopt::EX> extends the basic functionality of the L<Getopt> family to support
user-definable option aliases, and dynamic modules which work together
with a script through the option interface.

=head1 INTERFACES

There are two major interfaces to use L<Getopt::EX> modules.

The easier one is L<Getopt::Long> compatible module, L<Getopt::EX::Long>.
You can simply replace the module declaration and get the benefits of this
module to some extent.  It allows users to create a startup I<rc> file in
their home directory, which provides user-defined option aliases.

Use L<Getopt::EX::Loader> to get full capabilities.  Then the users of
your script can create their own extension modules which work together
with the original command through the command option interface.

Another module L<Getopt::EX::Colormap> is designed to produce colored text
on ANSI terminals, and to provide an easy way to maintain labeled colormap
tables and option handling.

=head2 L<Getopt::EX::Long>

This is the easiest way to get started with L<Getopt::EX>.  This
module is almost compatible with L<Getopt::Long> and drop-in
replaceable.

In addition, if the command name is I<example>,

    ~/.examplerc

file is loaded by default.  In this rc file, users can define their own
options with macro processing.  This is useful when the command takes
complicated arguments.  Users can also define default options which are
always used.  For example,

    option default -n

always gives the I<-n> option when the script is executed.  See the
L<Getopt::EX::Module> documentation for what you can do in this file.

If the rc file includes a section starting with C<__PERL__> or C<__PERL5__>,
it is evaluated as a Perl program.  Users can define any kind of functions
there, which can be invoked from command line options if the script is
aware of them.  At this time, the module object is assigned to the variable
C<$MODULE>, and you can access the module API through it.

Also, special command options preceded by B<-M> are recognized and the
corresponding Perl module is loaded.  For example,

    % example -Mfoo

will load C<App::example::foo> module.

This module is a normal Perl module, so users can write anything they
want.  If the module option comes with an initial function call, it is
called at the beginning of command execution.  Suppose that the module
I<foo> is specified like this:

    % example -Mfoo::bar(buz=100) ...

Then, after the module B<foo> is loaded, function I<bar> is called
with the parameter I<buz> with value 100.

If the module includes a C<__DATA__> section, it is interpreted just the
same as an rc file.  So you can define arbitrary options there.  Combined
with the startup function call described above, it is possible to control
module behavior by user-defined options.

=head2 L<Getopt::EX::Loader>

This module provides more primitive access to the underlying modules.
You should create loader object first:

  use Getopt::EX::Loader;
  my $loader = Getopt::EX::Loader->new(
      BASECLASS => 'App::example',
      );

Then load rc file:

  $loader->load_file("$ENV{HOME}/.examplerc");

Then process command line options:

  $loader->deal_with(\@ARGV);

Finally, pass the built-in functions declared in dynamically loaded modules
to the option parser.

  my $parser = Getopt::Long::Parser->new;
  $parser->getoptions( ... , $loader->builtins )

Actually, this is what L<Getopt::EX::Long> module is doing
internally.

=head2 L<Getopt::EX::Func>

To make your script communicate with user-defined subroutines, use the
L<Getopt::EX::Func> module, which provides the C<parse_func> interface.  If
your script has a B<--begin> option which tells the script to call a
specific function at the beginning of execution, write something
like:

    use Getopt::EX::Func qw(parse_func);
    GetOptions("begin:s" => \my $opt_begin);
    my $func = parse_func($opt_begin);
    $func->call;

Then the script can be invoked like this:

    % example -Mfoo --begin 'repeat(debug,msg=hello,count=2)'

See L<Getopt::EX::Func> for more detail.

=head2 L<Getopt::EX::Colormap>

This module is not tightly coupled with other modules in
L<Getopt::EX>.  It provides a concise way to specify ANSI terminal
colors with various effects, and produces terminal sequences by color
specification or label parameters.

You can use this module with normal L<Getopt::Long>:

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

In this example, users can change these colors from the command line option
like this:

    % example --colormap FILE=C,LINE=M,TEXT=Y

or call arbitrary perl function like:

    % example --colormap FILE='sub{uc}'

The above example produces an uppercase version of the provided string instead of
an ANSI color sequence.

If you want to use just coloring function, use backend module
L<Term::ANSIColor::Concise>.

=head2 L<Getopt::EX::LabeledParam>

This is the super-class of L<Getopt::EX::Colormap>.  L<Getopt::Long>
supports parameter handling within a hash,

    my %defines;
    GetOptions ("define=s" => \%defines);

and the parameter can be given in C<key=value> format.

    --define os=linux --define vendor=redhat

Using L<Getopt::EX::LabeledParam>, this can be written as:

    my @defines;
    my %defines;
    GetOptions ("defines=s" => \@defines);
    Getopt::EX::LabeledParam
        ->new(HASH => \%defines)
        ->load_params (@defines);

and the parameter can be given mixed together.

    --define os=linux,vendor=redhat

=head2 L<Getopt::EX::Numbers>

Parses number parameter descriptions and produces number range lists or
number sequences.  Number format is composed of four elements: C<start>,
C<end>, C<step> and C<length>, like this:

    1		1
    1:3		1,2,3
    1:20:5	1,     6,     11,       16
    1:20:5:3	1,2,3, 6,7,8, 11,12,13, 16,17,18

=head1 SEE ALSO

=head2 L<Term::ANSIColor::Concise>

The coloring capability of L<Getopt::EX::Colormap> is now implemented in
this module.

=head2 L<Getopt::EX::Hashed>

L<Getopt::EX::Hashed> is a module that automates a hash object to store
command line option values for L<Getopt::Long> and compatible modules
including B<Getopt::EX::Long>.

=head2 L<Getopt::EX::Config>

L<Getopt::EX::Config> provides an interface to define configuration
information for C<Getopt::EX> modules.  Using this module, it is
possible to define configuration information specific to the module and
to define module-specific command options.

=head2 L<Getopt::EX::i18n>

L<Getopt::EX::i18n> provides an easy way to set the locale environment
before executing a command.

=head2 L<Getopt::EX::termcolor>

L<Getopt::EX::termcolor> is a common module to manipulate system-dependent
terminal colors.

=head2 L<Getopt::EX::RPN>

L<Getopt::EX::RPN> provides an RPN (Reverse Polish Notation)
calculation interface for command line arguments.  This is convenient
when you want to define parameters based on terminal height or width.

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
