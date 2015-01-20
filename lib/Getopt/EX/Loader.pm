package Getopt::EX::Loader;

use strict;
use warnings;
use Carp;

use Exporter 'import';
our @EXPORT      = qw();
our %EXPORT_TAGS = ( );
our @EXPORT_OK   = qw();

use Data::Dumper;
use Getopt::EX::Container;

sub new {
    my $class = shift;

    my $obj = bless {
	RC => [],
	BASECLASS => undef,
	MODULE_OPT => '-M',
    }, $class;

    configure $obj @_ if @_;

    $obj;
}

sub configure {
    my $obj = shift;
    my %opt = @_;

    for my $opt (qw(BASECLASS MODULE_OPT)) {
	if (my $value = delete $opt{$opt}) {
	    $obj->{$opt} = $value;
	}
    }

    if (my $rc = delete $opt{RCFILE}) {
	my @rc = ref $rc eq 'ARRAY' ? @$rc : $rc;
	for (@rc) {
	    $obj->load(FILE => $_);
	}
    }

    warn "Unknown option: ", Dumper \%opt if %opt;

    $obj;
}

sub baseclass {
    my $obj = shift;
    @_  ? $obj->{BASECLASS} = shift
	: $obj->{BASECLASS};
}

sub rc {
    my $obj = shift;
    @{ $obj->{RC} };
}

sub append {
    my $obj = shift;
    push @{ $obj->{RC} }, @_;
}

sub load {
    my $obj = shift;
    my $rc = Getopt::EX::Container->new(@_, BASECLASS => $obj->baseclass);
    push @{$obj->{RC}}, $rc;
    $obj;
}

sub default {
    my $obj = shift;
    map { $_->default } $obj->rc;
}

sub call {
    my $obj = shift;
    map { $_->call } $obj->rc;
}

sub builtin {
    my $obj = shift;
    map { $_->builtin } $obj->rc;
}

sub deal_with {
    my $obj = shift;
    my $argv = shift;

    $obj->modopt($argv, @_);
    unshift @$argv, $obj->default;
    $obj->expand($argv, @_);

    $obj;
}

sub modopt {
    my $obj = shift;
    my $argv = shift;

    my $start = $obj->{MODULE_OPT} // return ();
    $start eq '' and return ();
    my $start_re = qr/\Q$start\E/;
    my @modules;
    while (@$argv) {
	if ($argv->[0] =~ /^$start_re(?<module>.+)/) {
	    shift @$argv;
	    push @modules, $obj->parseopt($+{module}, $argv);
	    next;
	}
	last;
    }
    @modules;
}

sub parseopt {
    my $obj = shift;
    my $mod = shift;
    my $argref = shift;
    my $base = $obj->baseclass;
    my $call;

    ##
    ## Check -Mmod::func(arg) or -Mmod::func=arg
    ##
    if ($mod =~ s{
	^ (?<name> .* ) ::
	  (?<call>
		\w+
		(?: (?<P>[(]) | = )  ## start with '(' or '='
		(?<arg> [^)]* )      ## optional arg list
		(?(<P>) [)] | )      ## close ')' or none
	  ) $
    }{$+{name}}x) {
	$call = $+{call};
    }

    my $rc = $obj->load(MODULE => $mod);

    my $module = "${base}::${mod}";

    if ($call) {
	$rc->call("${module}::${call}");
    }

    ##
    ## If &getopt is defined in module, call it and replace @ARGV.
    ##
    my $getopt = "${module}::getopt";
    if (defined &$getopt) {
	no strict 'refs';
	@$argref = &$getopt($rc, @$argref);
    }

    $rc;
}

sub expand {
    my $obj = shift;
    my $argv = shift;

    ##
    ## Process user defined option.
    ##
  ARGV:
    for (my $i = 0; $i < @$argv; $i++) {
	last if $argv->[$i] eq '--';
	my($opt, $value) = split /=/, $argv->[$i], 2;
	for my $rcdata ($obj->rc) {
	    if (my @s = $rcdata->getopt($opt)) {
		my @module = $obj->modopt(\@s);
		splice @$argv, $i, 1, ($opt, $value) if defined $value;
		##
		## Convert $<n> and $<shift>
		##
		my @rest = splice @$argv, $i;
		s/\$<(\d+)>/$rest[$1]/ge foreach @s;
		shift @rest;
		s/\$<shift>/shift @rest/ge foreach @s;
		
		my @default = map { $_->default } @module;
		push @$argv, @default, @s, @rest;
		redo ARGV;
	    }
	}
    }
}

sub modules {
    my $obj = shift;
    my $base = $obj->baseclass or return ();
    $base =~ s/::/\//g;

    grep { /^[a-z]/ }
    map  { /(\w+)\.pm$/ }
    map  { glob "$_/$base/*.pm" }
    @INC;
}

1;
