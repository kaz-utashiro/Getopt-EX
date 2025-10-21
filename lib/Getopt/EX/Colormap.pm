package Getopt::EX::Colormap;

our $VERSION = "2.3.1";

use v5.14;
use utf8;

use Exporter 'import';
our @EXPORT_OK = (
    qw( colorize colorize24 ansi_code ansi_pair csi_code ),
    qw( colortable colortable6 colortable12 colortable24 ),
    );
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use Carp;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use List::Util qw(min max first);

use parent 'Getopt::EX::LabeledParam';
use Getopt::EX::Util;
use Getopt::EX::Func qw(callable);

use Term::ANSIColor::Concise qw(:all);
{
    no strict 'refs';
    *colorize   = \&ansi_color;
    *colorize24 = \&ansi_color_24;
    for my $name (
	qw( NO_NO_COLOR
	    NO_COLOR
	    RGB24
	    LINEAR_256
	    LINEAR_GRAY
	    NO_RESET_EL
	    SPLIT_ANSI
	)) {
	*{$name} = *{"Term::ANSIColor::Concise::$name"};
    }
}

#use Term::ANSIColor::Concise::Table qw(:all);
sub AUTOLOAD {
    my $sub = our $AUTOLOAD =~ s/.*:://r;
    return if $sub eq 'DESTROY';
    if ($sub =~ /^colortable(?:|6|12|24)$/) {
	require Term::ANSIColor::Concise::Table
	    and Term::ANSIColor::Concise::Table->import(':all');
	goto &$sub;
    }
    die "Invalid call for $sub().\n";
}

our $NO_NO_COLOR //= $ENV{GETOPTEX_NO_NO_COLOR};
our $NO_COLOR    //= !$NO_NO_COLOR && defined $ENV{NO_COLOR};
our $RGB24       //= $ENV{COLORTERM}//'' eq 'truecolor' || $ENV{GETOPTEX_RGB24};
our $LINEAR_256  //= $ENV{GETOPTEX_LINEAR_256};
our $LINEAR_GRAY //= $ENV{GETOPTEX_LINEAR_GRAY};
our $NO_RESET_EL //= $ENV{GETOPTEX_NO_RESET_EL};
our $SPLIT_ANSI  //= $ENV{GETOPTEX_SPLIT_ANSI};

sub new {
    my $class = shift;
    my $obj = $class->SUPER::new;
    my %opt = @_;

    $obj->{CACHE} = {};
    $opt{CONCAT} //= "^"; # Reset character for LabeledParam object
    $opt{RESET} = '@';
    $obj->configure(%opt);

    $obj;
}

sub index_color {
    my $obj = shift;
    my $index = shift;
    my $text = shift;

    my $list = $obj->{LIST};
    if (@$list) {
	$text = $obj->color($list->[$index % @$list], $text, $index);
    }
    $text;
}

sub color {
    my $obj = shift;
    my $color = shift;
    my $text = shift;

    my $map = $obj->{HASH};
    my $c = exists $map->{$color} ? $map->{$color} : $color;

    return $text unless $c;

    cached_ansi_color($obj->{CACHE}, $c, $text);
}

sub colormap {
    my $obj = shift;
    my %opt = (
	name   => "--newopt",
	option => "--colormap",
	sort   => "length",
	@_
    );

    my $hash = $obj->{HASH};
    join "\n", (
	"option $opt{name} \\",
	do {
	    my $maxlen = $opt{noalign} ? "" : do {
		max map { length } keys %{$hash};
	    };
	    my $format = "\t%s %${maxlen}s=%s \\";
	    my $compare = do {
		if ($opt{sort} eq "length") {
		    sub { length $a <=> length $b or $a cmp $b };
		} else {
		    sub { $a cmp $b };
		}
	    };
	    map {
		sprintf $format, $opt{option}, $_, $hash->{$_} // "";
	    } sort $compare keys %{$hash};
	},
	"\t\$<ignore>\n",
	);
}

1;

__END__


=head1 NAME

Getopt::EX::Colormap - ANSI terminal color and option support


=head1 SYNOPSIS

  GetOptions('colormap|cm:s' => @opt_colormap);

  require Getopt::EX::Colormap;
  my $cm = Getopt::EX::Colormap
      ->new
      ->load_params(@opt_colormap);

  print $cm->color('FILE', 'FILE labeled text');

  print $cm->index_color($index, 'TEXT');


=head1 DESCRIPTION

Text coloring capability is not tightly bound to option processing,
but it may be useful to provide a simple uniform way to specify
complicated color settings from the command line.

The coloring function is now implemented in a different module
L<Term::ANSIColor::Concise>.  Details about color specifications are described in
its documentation.

This module assumes color information is given in two ways: one as a
labeled list, and one as an indexed list.

The handler maintains hash and list objects, and labeled colors are stored
in the hash, while indexed colors are in the list automatically.  Users can mix both
specifications.

=head2 LABELED COLOR

This is an example of labeled list:

    --cm 'COMMAND=SE,OMARK=CS,NMARK=MS' \
    --cm 'OTEXT=C,NTEXT=M,*CHANGE=BD/445,DELETE=APPEND=RD/544' \
    --cm 'CMARK=GS,MMARK=YS,CTEXT=G,MTEXT=Y'

Color definitions are separated by commas (C<,>) and the label is
specified by I<LABEL=> style prefix.  Multiple labels can be set
for the same value by connecting them together.  Label names can be
specified with C<*> and C<?> wildcard characters.

If the color spec starts with a plus (C<+>) mark in the labeled list
format, it is appended to the current value with a reset mark (C<^>).
The next example uses a wildcard to set all labels ending with `CHANGE' to `R'
and sets `R^S' to the `OCHANGE' label.

    --cm '*CHANGE=R,OCHANGE=+S'

=head2 INDEX COLOR

An indexed list example is like this:

    --cm 555/100,555/010,555/001 \
    --cm 555/011,555/101,555/110 \
    --cm 555/021,555/201,555/210 \
    --cm 555/012,555/102,555/120

This is an example of an RGB 6x6x6 216 colors specification.  The left side
of the slash is for foreground, and the right side is for background color.  This
color list is accessed by index.

If the special reset symbol C<@> is encountered, the index list is
reset to empty at that point.

=head2 CALLING FUNCTIONS

Besides producing ANSI colored text, this module supports calling
arbitrary function to handle a string.  See L<FUNCTION SPEC> section
for more detail.

=head1 FUNCTION SPEC

It is also possible to set an arbitrary function which is called to
handle a string in place of color, and that is not necessarily concerned
with color.  This scheme is quite powerful and the module name itself
may be somewhat misleading.  A spec string which starts with C<sub{> is
considered a function definition.  So

    % example --cm 'sub{uc}'

sets the function object in the color entry.  And when the C<color> method
is called with that object, the specified function is called instead of
producing an ANSI color sequence.  The function is supposed to get the target
text as a global variable C<$_>, and return the result as a string.
The function C<sub{uc}> in the above example returns an uppercase version of
C<$_>.

If your script prints a file name according to the color spec labeled by
B<FILE>, then

    % example --cm FILE=R

prints the file name in red, but

    % example --cm FILE=sub{uc}

will print the name in uppercases.

A spec starting with C<&> is considered a function name.  If the
function C<double> is defined like:

    sub double { $_ . $_ }

then the command

    % example --cm '&double'

produces doubled text by the C<color> method.  Functions can also take
parameters, so the next example

    sub repeat {
	my %opt = @_;
	$_ x $opt{count} // 1;
    }

    % example --cm '&repeat(count=3)'

produces tripled text.

The function object is created by the L<Getopt::EX::Func> module.  Take a look
at the module for details.


=head1 EXAMPLE CODE

    #!/usr/bin/env perl
    
    use strict;
    use warnings;
    
    my @opt_colormap;
    use Getopt::EX::Long;
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
    
    for (keys @colors) {
        print $handler->index_color($_, "COLOR $_"), "\n";
    }
    
    for (sort keys %colormap) {
        print $handler->color($_, $_), "\n";
    }

This sample program is complete to work.  If you save this script as a
file F<example>, try to put following contents in F<~/.examplerc> and
see what happens.

    option default \
        --cm 555/100,555/010,555/001 \
        --cm 555/011,555/101,555/110 \
        --cm 555/021,555/201,555/210 \
        --cm 555/012,555/102,555/120


=head1 METHOD

=over 4

=item B<color> I<label>, TEXT

=item B<color> I<color_spec>, TEXT

Return colored text indicated by label or color spec string.

=item B<index_color> I<index>, TEXT

Return colored text indicated by I<index>.  If the index is larger
than the color list, it wraps around.

=item B<new>

=item B<append>

=item B<load_params>

See super class L<Getopt::EX::LabeledParam>.

=item B<colormap>

Return a string which can be used for option definition.  Some
parameters can be specified like:

    $obj->colormap(name => "--newopt", option => "--colormap");

=over 4

=item B<name>

Specify new option name.

=item B<option>

Specify option name for colormap setup.

=item B<sort>

The default value is C<length> and sorts options by their length.  Use
C<alphabet> to sort them alphabetically.

=item B<noalign>

Colormap labels are aligned so that `=' marks are lined up vertically.
Give a true value to the B<noalign> parameter if you don't like this
behavior.

=back

=back


=head1 FUNCTION

These functions are now implemented in the L<Term::ANSIColor::Concise>
module with slightly different names.  The interface is retained for
compatibility but using them in new code is strongly discouraged.

=over 4

=item B<colorize>(I<color_spec>, I<text>)

=item B<colorize24>(I<color_spec>, I<text>)

Return colorized version of given text.

B<colorize> produces 256 or 24-bit colors depending on the setting,
while B<colorize24> always produces 24-bit color sequences for
24-bit/12-bit color specs.  See L<ENVIRONMENT>.

=item B<ansi_code>(I<color_spec>)

Produces an introducer sequence for the given spec.  A reset code can be obtained
by B<ansi_code("Z")>.

=item B<ansi_pair>(I<color_spec>)

Produces introducer and recovery sequences for the given spec. The recovery
sequence includes I<Erase Line> related controls along with a simple SGR reset
code.

=item B<csi_code>(I<name>, I<params>)

Produces a CSI (Control Sequence Introducer) sequence by name with
numeric parameters.  I<name> is one of CUU, CUD, CUF, CUB, CNL, CPL,
CHA, CUP, ED, EL, SU, SD, HVP, SGR, SCP, RCP.

=item B<colortable>([I<width>])

Prints a visual 256 color matrix table on the screen.  The default I<width>
is 144.  Use it like this:

    perl -MGetopt::EX::Colormap=colortable -e colortable

=back

=head1 ENVIRONMENT

Environment variables are also implemented in a slightly different way in the
L<Term::ANSIColor::Concise> module.  Use C<ANSICOLOR_NO_NO_COLOR>,
C<ANSICOLOR_RGB24>, C<ANSICOLOR_NO_RESET_EL> if you are using a newer
version.

If the environment variable C<NO_COLOR> is set, regardless of its
value, the colorizing interface in this module never produces color
sequences.  Primitive functions such as C<ansi_code> are not affected.
See L<https://no-color.org/>.

If the module variable C<$NO_NO_COLOR> or the C<GETOPTEX_NO_NO_COLOR>
environment variable is true, the C<NO_COLOR> value is ignored.

The B<color> method and B<colorize> function produce 256 or 24-bit colors
depending on the value of the C<$RGB24> module variable.  Also, 24-bit mode
is enabled when the C<GETOPTEX_RGB24> environment variable is set or C<COLORTERM>
is C<truecolor>.

If the module variable C<$NO_RESET_EL> is set, or the C<GETOPTEX_NO_RESET_EL>
environment variable is set, the I<Erase Line> sequence is not produced after a RESET code.
See L<RESET SEQUENCE>.


=head1 SEE ALSO

L<Getopt::EX>,
L<Getopt::EX::LabeledParam>

L<Term::ANSIColor::Concise>

L<https://en.wikipedia.org/wiki/ANSI_escape_code>

L<https://en.wikipedia.org/wiki/X11_color_names>

L<https://no-color.org/>

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

#  LocalWords:  colormap colorize Cyan RGB cyan Wikipedia CSI ansi
#  LocalWords:  SGR
