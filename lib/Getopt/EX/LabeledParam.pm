package Getopt::EX::LabeledParam;
use version; our $VERSION = version->declare("2.1.6");

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

This module implements super class of L<Getopt::EX::Colormap>.

Parameters can be given in two ways: one in labeled table, and one in
indexed list.

Handler maintains hash and list objects, and labeled values are stored
in hash, non-label values are in list automatically.  User can mix
both specifications.

When the value field has a special form of function call,
L<Getopt::EX::Func> object is created and stored for that entry.  See
L<FUNCTION SPEC> section in L<Getopt::EX::Colormap> for more detail.

=head2 HASH

Basically, labeled parameter is defined by B<LABEL>=I<VALUE> notation:

    FILE=R

Definition can be connected by comma (C<,>):

    FILE=R,LINE=G

Multiple labels can be set for same value:

    FILE=LINE=TEXT=R

Wildcard C<*> and C<?> can be used in label name, and they matches
existing hash key name.  If labels C<OLD_FILE> and C<NEW_FILE> exists
in hash,

    *FILE=R

and

    OLD_FILE=NEW_FILE=R

produces same result.

If B<VALUE> part start with plus (C<+>) character, it is appended to
current value.  At this time, C<CONCAT> string is inserted before
additional string.  Default C<CONCAT> strings is empty, so use
configure method to set.  If B<VALUE> part start with minus (C<->)
character, following characters are deleted from the current value.

=head2 LIST

If B<LABEL>= part is omitted, values are treated anonymous list and
stored in list object.  For example,

    R,G,B,C,M,Y

makes six entries in the list.  The list object is accessed by index,
rather than label.

=head1 METHODS

=over 4

=item B<new>

=item B<configure>

=over 4

=item B<HASH> =E<gt> I<hashref>

=item B<LIST> =E<gt> I<listref>

B<HASH> and B<LIST> reference can be set by B<new> or B<configure>
method.  You can provide default setting of hash and list, and it is
usually easier to access those values directly, rather than through
class methods.

=item B<NEWLABEL> =E<gt> 0/1

By default, B<load_params> does not create new entry in hash table,
and absent label is ignored.  Setting <NEWLABEL> parameter true makes
it possible create a new hash entry.

=item B<CONCAT> =E<gt> I<string>

Set concatenation string inserted before appending string.

=item B<RESET> =E<gt> I<string>

Set B<reset> mark.  Undefined by default.  If this reset string is
found in a list-type argument, the list is reset to empty.

=back

=item B<load_params> I<option>

Load option list into the object.

=item B<append> HASHREF or LIST

Provide simple interface to append colormap hash or color list.  If a
hash reference is given, all entry of the hash is appended to the
colormap.  Otherwise, they are appended anonymous color list.

=back

=head1 SEE ALSO

L<Getopt::EX::Colormap>

#  LocalWords:  CONCAT hashref listref NEWLABEL HASHREF colormap
