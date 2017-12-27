package App::example::mode_wildcard;
use strict;
use warnings;

sub initialize {
    my $mod = shift;
    $mod->mode(wildcard => 1);
}

1;

__DATA__

option --expm lib/Getopt/*.pm

option --wildcard $<shift>
