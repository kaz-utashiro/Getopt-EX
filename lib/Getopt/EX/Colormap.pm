package Getopt::EX::Colormap;

our $VERSION = "2.2.1";

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

Text coloring capability is not strongly bound to option processing,
but it may be useful to give a simple uniform way to specify
complicated color setting from command line.

Coloring function is now implemented in different module
L<Term::ANSIColor::Concise>.  Detail about color spec is described in
its document.

This module assumes color information is given in two ways: one in
labeled list, and one in indexed list.

Handler maintains hash and list objects, and labeled colors are stored
in hash, index colors are in list automatically.  User can mix both
specifications.

=head2 LABELED COLOR

This is an example of labeled list:

    --cm 'COMMAND=SE,OMARK=CS,NMARK=MS' \
    --cm 'OTEXT=C,NTEXT=M,*CHANGE=BD/445,DELETE=APPEND=RD/544' \
    --cm 'CMARK=GS,MMARK=YS,CTEXT=G,MTEXT=Y'

Color definitions are separated by comma (C<,>) and the label is
specified by I<LABEL=> style precedence.  Multiple labels can be set
for same value by connecting them together.  Label name can be
specified with C<*> and C<?> wildcard characters.

If the color spec start with plus (C<+>) mark with the labeled list
format, it is appended to the current value with reset mark (C<^>).
Next example uses wildcard to set all labels end with `CHANGE' to `R'
and set `R^S' to `OCHANGE' label.

    --cm '*CHANGE=R,OCHANGE=+S'

=head2 INDEX COLOR

Indexed list example is like this:

    --cm 555/100,555/010,555/001 \
    --cm 555/011,555/101,555/110 \
    --cm 555/021,555/201,555/210 \
    --cm 555/012,555/102,555/120

This is an example of RGB 6x6x6 216 colors specification.  Left side
of slash is foreground, and right side is for background color.  This
color list is accessed by index.

If the special reset symbol C<@> is encountered, the index list is
reset to empty at that point.

=head2 CALLING FUNCTIONS

Besides producing ANSI colored text, this module supports calling
arbitrary function to handle a string.  See L<FUNCTION SPEC> section
for more detail.

=head1 FUNCTION SPEC

It is also possible to set arbitrary function which is called to
handle string in place of color, and that is not necessarily concerned
with color.  This scheme is quite powerful and the module name itself
may be somewhat misleading.  Spec string which start with C<sub{> is
considered as a function definition.  So

    % example --cm 'sub{uc}'

set the function object in the color entry.  And when C<color> method
is called with that object, specified function is called instead of
producing ANSI color sequence.  Function is supposed to get the target
text as a global variable C<$_>, and return the result as a string.
Function C<sub{uc}> in the above example returns uppercase version of
C<$_>.

If your script prints file name according to the color spec labeled by
B<FILE>, then

    % example --cm FILE=R

prints the file name in red, but

    % example --cm FILE=sub{uc}

will print the name in uppercases.

Spec start with C<&> is considered as a function name.  If the
function C<double> is defined like:

    sub double { $_ . $_ }

then, command

    % example --cm '&double'

produces doubled text by C<color> method.  Function can also take
parameters, so the next example

    sub repeat {
	my %opt = @_;
	$_ x $opt{count} // 1;
    }

    % example --cm '&repeat(count=3)'

produces tripled text.

Function object is created by <Getopt::EX::Func> module.  Take a look
at the module for detail.


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

Return colored text indicated by I<index>.  If the index is bigger
than color list, it rounds up.

=item B<new>

=item B<append>

=item B<load_params>

See super class L<Getopt::EX::LabeledParam>.

=item B<colormap>

Return string which can be used for option definition.  Some
parameters can be specified like:

    $obj->colormap(name => "--newopt", option => "--colormap");

=over 4

=item B<name>

Specify new option name.

=item B<option>

Specify option name for colormap setup.

=item B<sort>

Default value is C<length> and sort options by their length.  Use
C<alphabet> to sort them alphabetically.

=item B<noalign>

Colormap label is aligned so that `=' marks are lined vertically.
Give true value to B<noalign> parameter, if you don't like this
behavior.

=back

=back


=head1 FUNCTION

These functions are now implemented in L<Term::ANSIColor::Concise>
module by slightly different names.  Interface is remained for
compatibility but using them in the new code is strongly discouraged.

=over 4

=item B<colorize>(I<color_spec>, I<text>)

=item B<colorize24>(I<color_spec>, I<text>)

Return colorized version of given text.

B<colorize> produces 256 or 24bit colors depending on the setting,
while B<colorize24> always produces 24bit color sequence for
24bit/12bit color spec.  See L<ENVIRONMENT>.

=item B<ansi_code>(I<color_spec>)

Produces introducer sequence for given spec.  Reset code can be taken
by B<ansi_code("Z")>.

=item B<ansi_pair>(I<color_spec>)

Produces introducer and recover sequences for given spec. Recover
sequence includes I<Erase Line> related control with simple SGR reset
code.

=item B<csi_code>(I<name>, I<params>)

Produce CSI (Control Sequence Introducer) sequence by name with
numeric parameters.  I<name> is one of CUU, CUD, CUF, CUB, CNL, CPL,
CHA, CUP, ED, EL, SU, SD, HVP, SGR, SCP, RCP.

=item B<colortable>([I<width>])

Print visual 256 color matrix table on the screen.  Default I<width>
is 144.  Use like this:

    perl -MGetopt::EX::Colormap=colortable -e colortable

=back

=head1 ENVIRONMENT

Environment variables are also implemented in slightly different way
L<Term::ANSIColor::Concise> module.  Use C<ANSICOLOR_NO_NO_COLOR>,
C<ANSICOLOR_RGB24>, C<ANSICOLOR_NO_RESET_EL> if you are using newer
version.

If the environment variable C<NO_COLOR> is set, regardless of its
value, colorizing interface in this module never produce color
sequence.  Primitive function such as C<ansi_code> is not the case.
See L<https://no-color.org/>.

If the module variable C<$NO_NO_COLOR> or C<GETOPTEX_NO_NO_COLOR>
environment is true, C<NO_COLOR> value is ignored.

B<color> method and B<colorize> function produces 256 or 24bit colors
depending on the value of C<$RGB24> module variable.  Also 24bit mode
is enabled when environment C<GETOPTEX_RGB24> is set or C<COLORTERM>
is C<truecolor>.

If the module variable C<$NO_RESET_EL> set, or C<GETOPTEX_NO_RESET_EL>
environment, I<Erase Line> sequence is not produced after RESET code.
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

Copyright 2015-2024 Kazumasa Utashiro

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#  LocalWords:  colormap colorize Cyan RGB cyan Wikipedia CSI ansi
#  LocalWords:  SGR
