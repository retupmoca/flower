#!/usr/bin/env perl6

class FooBar {
  method amethod ($name) {
    return "Hello $name";
  }
}

BEGIN { @*INC.unshift: './lib' }

use Test;
use Flower;

plan 1;

my $xml = '<?xml version="1.0"?>';

my $template = '<test><query tal:replace="perl:ahash<anobj>.amethod(\'world\')"/></test>';
my $flower = Flower.new(:template($template));

my %ahash = {
  'anobj' => FooBar.new,
}

$flower.load-modifiers('Perl');

is $flower.parse(ahash => %ahash), $xml~'<test>Hello world</test>', 'perl: modifier';
