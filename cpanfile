requires 'perl' => 5.014;

requires 'List::Util' => 1.45;

requires 'Moo' => 1.001000;

requires 'Graphics::ColorNames';

on 'test' => sub {
    requires 'Test::More' => 0.98;
};

