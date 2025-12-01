use v5.14;
use warnings;
use Test::More;
use Data::Dumper;

use Getopt::EX::Func;

*arg2kvlist = \&Getopt::EX::Func::arg2kvlist;

is_deeply([ arg2kvlist("arg1") ],
	  [ arg1 => 1 ], "no value");

is_deeply([ arg2kvlist("arg2=2") ],
	  [ arg2 => 2 ], "with value");

is_deeply([ arg2kvlist("arg1,arg2=2") ],
	  [ arg1 => 1, arg2 => 2 ], "mix");

is_deeply([ arg2kvlist("arg1,arg2=2,arg3=0") ],
	  [ arg1 => 1, arg2 => 2, arg3 => 0 ], "value 0");

is_deeply([ arg2kvlist("arg1,arg2=2,arg3=three") ],
	  [ arg1 => 1, arg2 => 2, arg3 => "three" ], "mix string");

is_deeply([ arg2kvlist("arg1,arg2=2,arg3=sub(),arg4") ],
	  [ arg1 => 1, arg2 => 2,
	    arg3 => "sub()", arg4 => 1 ], "paren");

is_deeply([ arg2kvlist("arg1,arg2=2,arg3=sub(x=1,y=sub(z(a,b))),arg4") ],
	  [ arg1 => 1, arg2 => 2,
	    arg3 => "sub(x=1,y=sub(z(a,b)))", arg4 => 1 ], "nested paren");

# *= takes the rest of the string
is_deeply([ arg2kvlist("arg1,arg2*=a,b,c") ],
	  [ arg1 => 1, arg2 => "a,b,c" ], "*= takes rest");

is_deeply([ arg2kvlist("key*=value=with=equals") ],
	  [ key => "value=with=equals" ], "*= with equals in value");

# /= uses next char as delimiter
is_deeply([ arg2kvlist("key/=,a,b,c,") ],
	  [ key => "a,b,c" ], "/= with comma delimiter");

is_deeply([ arg2kvlist("key/=/path/to/file/") ],
	  [ key => "path/to/file" ], "/= with slash delimiter");

is_deeply([ arg2kvlist("arg1,arg2/=|x,y,z|,arg3") ],
	  [ arg1 => 1, arg2 => "x,y,z", arg3 => 1 ], "/= in middle");

is_deeply([ arg2kvlist("key/=:a=b,c=d:") ],
	  [ key => "a=b,c=d" ], "/= with colon delimiter");

is_deeply([ arg2kvlist("a/=,x,y,,b/=|p|q|") ],
	  [ a => "x,y", b => "p|q" ], "/= multiple times with different delimiters");

is_deeply([ arg2kvlist("a/=,x,y,,b/=,p,q,") ],
	  [ a => "x,y", b => "p,q" ], "/= multiple times with same delimiter");

# control character as delimiter
is_deeply([ arg2kvlist("key/=\x07a,b,c\x07") ],
	  [ key => "a,b,c" ], "/= with BEL delimiter");

is_deeply([ arg2kvlist("key/=\x1fa,b,c\x1f") ],
	  [ key => "a,b,c" ], "/= with US delimiter");

is_deeply([ arg2kvlist("key/=\x00a,b,c\x00") ],
	  [ key => "a,b,c" ], "/= with NULL delimiter");

done_testing;

1;
