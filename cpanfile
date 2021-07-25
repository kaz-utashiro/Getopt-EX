requires 'perl' => v5.14;

requires 'Getopt::Long';

requires 'List::Util' => 1.29;
requires 'Hash::Util';

requires 'Graphics::ColorNames';

on 'test' => sub {
    requires 'Test::More' => 0.98;
};

