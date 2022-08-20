requires 'perl' => v5.14;

requires 'Getopt::Long', '2.39';

requires 'List::Util' => 1.29;
requires 'Hash::Util';

requires 'Graphics::ColorNames';

requires 'Term::ANSIColor::Concise', '== 2.00_03';

on 'test' => sub {
    requires 'Test::More' => 0.98;
};

