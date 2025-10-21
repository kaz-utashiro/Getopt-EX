package Getopt::EX::LabeledParam;

our $VERSION = "2.3.1";

use v5.14;
use warnings;
use Carp;

use Exporter 'import';
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use Data::Dumper;
use Getopt::EX::Module;
use Getopt::EX::Func qw(parse_func);

sub new {
    my $class = shift;

    my $obj = bless {
	NEWLABEL => 0,
	CONCAT => "",
	HASH => {},
	LIST => [],
	RESET => undef,
    }, $class;

    $obj->configure(@_) if @_;

    $obj;
}

sub configure {
    my $obj = shift;
    while (@_ >= 2) {
	my($k, $v) = splice @_, 0, 2;
	if ($k =~ /^\w/ and exists $obj->{$k}) {
	    $obj->{$k} = $v;
	}
    }
    $obj;
}

sub get_hash { shift->{HASH} }

sub set_hash {
    my $obj = shift;
    %{ $obj->{HASH} } = @_;
    $obj;
}

sub list { @{ shift->{LIST} } }

sub push_list {
    my $obj = shift;
    for (@_) {
	if (defined $obj->{RESET} and $_ eq $obj->{RESET}) {
	    @{ $obj->{LIST} } = ();
	} else {
	    push @{ $obj->{LIST} }, $_;
	}
    }
    $obj;
}

sub set_list {
    my $obj = shift;
    @{ $obj->{LIST} } = @_;
    $obj;
}

sub append {
    my $obj = shift;
    for my $item (@_) {
	if (ref $item eq 'ARRAY') {
	    push @{$obj->{LIST}}, @$item;
	}
	elsif (ref $item eq 'HASH') {
	    while (my($k, $v) = each %$item) {
		$obj->{HASH}->{$k} = $v;
	    }
	}
	else {
	    push @{$obj->{LIST}}, $item;
	}
    }
}

sub load_params {
    my $obj = shift;

    my $re_field = qr/[\w\*\?]+/;
    map {
	my $spec = pop @$_;
	my @spec;
	while ($spec =~ s/\&([:\w]+ (?: \( [^)]* \) )? ) ;?//x) { # &func
	    push @spec, parse_func({ PACKAGE => 'main' }, $1);
	}
	if ($spec =~ s/\b(sub\s*{.*)//) { # sub { ... }
	    push @spec, parse_func({ PACKAGE => 'main' }, $1);
	}
	push @spec, $spec if $spec ne '';
	my $c = @spec > 1 ? [ @spec ] : @spec == 1 ? $spec[0] : "";
	if (@$_ == 0) {
	    $obj->push_list($c);
	}
	else {
	    map {
		if ($c =~ /^\++(.*)/) { # LABEL=+ATTR
		    $obj->{HASH}->{$_} .= $obj->{CONCAT} . "$1";
		}
		elsif ($c =~ /^\-+(.*)$/i) { # LABEL=-ATTR
		    my $chars = $1 =~ s/(?=\W)/\\/gr;
		    $obj->{HASH}->{$_} =~ s/[$chars]+//g;
		}
		else {
		    $obj->{HASH}->{$_} = $c;
		}
	    }
	    map {
		# plain label
		if (not /\W/) {
		    if (exists $obj->{HASH}->{$_}) {
			$_;
		    } else {
			if ($obj->{NEWLABEL}) {
			    $_;
			} else {
			    warn "$_: Unknown label\n";
			    ();
			}
		    }
		}
		# wild card
		else {
		    my @labels = match_glob($_, keys %{$obj->{HASH}});
		    if (@labels == 0) {
			warn "$_: Unmatched label\n";
		    }
		    @labels;
		}
	    }
	    @$_;
	}
    }
    map {
	if (my @field = /\G($re_field)=/gp) {
	    [ @field, ${^POSTMATCH} ];
	} else {
	    [ $_ ];
	}
    }
    map {
	m/( (?: $re_field= )*
	    (?: .* \b sub \s* \{ .*
	      | (?: \([^)]*\) | [^,\s] )+
	    )
	  )/gx;
    }
    @_;

    $obj;
}

sub match_glob {
    local $_ = shift;
    s/\?/./g;
    s/\*/.*/g;
    my $regex = qr/^$_$/;
    grep { $_ =~ $regex } @_;
}

1;

=head1 NAME

Getopt::EX::LabeledParam - Labeled parameter handling


=head1 SYNOPSIS

  GetOptions('colormap|cm:s' => @opt_colormap);

  # default values
  my %colormap = ( FILE => 'DR', LINE => 'Y', TEXT => '' );
  my @colors = qw( /544 /545 /445 /455 /545 /554 );

  require Getopt::EX::LabeledParam;
  my $cmap = Getopt::EX::LabeledParam
      ->new( NEWLABEL => 0,
             HASH => \%colormap,
             LIST => \@colors )
      ->load_params(@opt_colormap);


=head1 DESCRIPTION

This module implements the super class of L<Getopt::EX::Colormap>.

Parameters can be given in two ways: one as a labeled table, and one as an
indexed list.

The handler maintains hash and list objects, and labeled values are stored
in the hash, while non-label values are in the list automatically.  Users can mix
both specifications.

When the value field has a special form of a function call, a
L<Getopt::EX::Func> object is created and stored for that entry.  See the
L<FUNCTION SPEC> section in L<Getopt::EX::Colormap> for more details.

=head2 HASH

Basically, labeled parameter is defined by B<LABEL>=I<VALUE> notation:

    FILE=R

Definitions can be connected by commas (C<,>):

    FILE=R,LINE=G

Multiple labels can be set for same value:

    FILE=LINE=TEXT=R

Wildcards C<*> and C<?> can be used in label names, and they match
existing hash key names.  If labels C<OLD_FILE> and C<NEW_FILE> exist
in the hash,

    *FILE=R

and

    OLD_FILE=NEW_FILE=R

produces the same result.

If the B<VALUE> part starts with a plus (C<+>) character, it is appended to the
current value.  At this time, the C<CONCAT> string is inserted before the
additional string.  The default C<CONCAT> string is empty, so use the
configure method to set it.  If the B<VALUE> part starts with a minus (C<->)
character, the following characters are deleted from the current value.

=head2 LIST

If the B<LABEL>= part is omitted, values are treated as an anonymous list and
stored in the list object.  For example,

    R,G,B,C,M,Y

makes six entries in the list.  The list object is accessed by index
rather than by label.

=head1 METHODS

=over 4

=item B<new>

=item B<configure>

=over 4

=item B<HASH> =E<gt> I<hashref>

=item B<LIST> =E<gt> I<listref>

B<HASH> and B<LIST> references can be set by the B<new> or B<configure>
method.  You can provide default settings for the hash and list, and it is
usually easier to access those values directly rather than through
class methods.

=item B<NEWLABEL> =E<gt> 0/1

By default, B<load_params> does not create a new entry in the hash table,
and absent labels are ignored.  Setting the B<NEWLABEL> parameter to true makes
it possible to create a new hash entry.

=item B<CONCAT> =E<gt> I<string>

Set the concatenation string inserted before appending a string.

=item B<RESET> =E<gt> I<string>

Set the B<reset> mark.  Undefined by default.  If this reset string is
found in a list-type argument, the list is reset to empty.

=back

=item B<load_params> I<option>

Load the option list into the object.

=item B<append> HASHREF or LIST

Provides a simple interface to append a colormap hash or color list.  If a
hash reference is given, all entries of the hash are appended to the
colormap.  Otherwise, they are appended to the anonymous color list.

=back

=head1 SEE ALSO

L<Getopt::EX::Colormap>

#  LocalWords:  CONCAT hashref listref NEWLABEL HASHREF colormap
