package Getopt::EX::LabeledParam;

use strict;
use warnings;
use Carp;

use Exporter 'import';
our @EXPORT      = qw();
our @EXPORT_OK   = qw();
our %EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use Data::Dumper;
use Getopt::EX::Container;
use Getopt::EX::Func qw(parse_func);

sub new {
    my $class = shift;

    my $obj = bless {
	newlabel => 0,
	HASH => {},
	LIST => [],
    }, $class;

    configure $obj @_;

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
    push @{ $obj->{LIST} }, @_;
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
	while ($spec =~ s/\&(\w+ (?: \( [^)]* \) )? ) ;?//x) { # &func
	    push @spec, parse_func({ PACKAGE => 'main' }, $1);
	}
	if ($spec =~ s/\b(sub\s*{.*)//) { # sub { ... }
	    push @spec, parse_func($1);
	}
	push @spec, $spec if $spec ne "";
	my $c = @spec > 1 ? [ @spec ] : $spec[0];
	if (@$_ == 0) {
	    $obj->push_list($c);
	}
	else {
	    map { $obj->{HASH}->{$_} = $c }
	    map {
		if (!/\W/ and $obj->{newlabel}) {
		    $_;
		} else {
		    match_glob($_, keys %{$obj->{HASH}})
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
