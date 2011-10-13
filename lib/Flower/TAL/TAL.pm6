#use Flower::Lang;
class Flower::TAL::TAL; #does Flower::Lang; 

## The TAL XML Application Language

use Exemel;

use Flower::TAL::TALES;  ## The TALES attribute sub-language.
use Flower::TAL::Repeat; ## A class representing our repeat object.

has $.default-tag = 'tal';  ## What to use if nothing is set.
has $.ns = 'http://xml.zope.org/namespaces/tal';

## The full set of TAL attributes.
## Ones marked 'safe' can be used if the :safe rule is passed.
has @.handlers =
  'define'       => { :safe },
  'condition',
  'repeat',
  'attributes'   => { :method<parse-attrs>, :safe },
  'attrs'        => { :safe }, ## non-standard extension for lazy people.
  'content'      => { :safe },
  'replace',
  'omit-tag'     => 'parse-omit',
  'block'        => { :element }; ## lazy <tal:block> extension from PHPTAL.

has $.tales;

## Common methods for Flower Languages.
## This is in Flower::Lang role, but due to bugs with having
## multiple classes using the same roles in Rakudo ng, I've simply
## copied and pasted it. Oh, I can't wait until this works on "nom".

has $.flower;
has $.custom-tag is rw;
has %.options;

method tag {
  if $.custom-tag.defined {
    return $.custom-tag;
  }
  return $.default-tag;
}

## Normally we'd use submethod BUILD but in "ng" at least, it
## completely wipes out our defaults in the "has" statements.
## Boo, hiss. So now we have this lovely bit of magic instead.
method init () {
  $!tales  = Flower::TAL::TALES.new(:parent(self));
}

## This is super simple, as a <tal:block> acts the
## same as a normal element with a  tal:omit-tag="" rule.
method parse-block ($element is rw, $name) {
  $element = $element.nodes;
}

method parse-define ($xml is rw, $tag) {
  my @statements = $xml.attribs{$tag}.split(/\;\s+/);
  for @statements -> $statement {
    my ($attrib, $query) = $statement.split(/\s+/, 2);
    my $val = $.tales.query($query);
    if defined $val { $.flower.data{$attrib} = $val; }
  }
  $xml.unset($tag);
}

method parse-condition ($xml is rw, $tag) {
  if $.tales.query($xml.attribs{$tag}, :bool) {
    $xml.unset($tag);
  } else {
    $xml = Nil;
  }
}

method parse-content ($xml is rw, $tag) {
  my $node = $.tales.query($xml.attribs{$tag}, :forcexml);
  if defined $node {
    if $node === $xml.nodes {} # special case for 'default'.
    else {
      $xml.nodes.splice;
      $xml.nodes.push: $node;
    }
  }
  $xml.unset: $tag;
}

method parse-replace ($xml is rw, $tag) {
  my $text = $xml.attribs{$tag};
  if defined $text {
    $xml = $.tales.query($text, :forcexml); 
  }
  else {
    $xml = Nil;
  }
}

method parse-attrs ($xml is rw, $tag) {
  my @statements = $xml.attribs{$tag}.split(/\;\s+/);
  for @statements -> $statement {
    my ($attrib, $query) = $statement.split(/\s+/, 2);
    my $val = $.tales.query($query, :noxml);
    if defined $val {
      $xml.set($attrib, $val);
    }
  }
  $xml.unset: $tag;
}

method parse-repeat ($xml is rw, $tag) { 
  my ($attrib, $query) = $xml.attribs{$tag}.split(/\s+/, 2);
  my $array = $.tales.query($query);
  if (defined $array && $array ~~ Array) {
    if (! $.flower.data.exists('repeat') || $.flower.data<repeat> !~~ Hash) {
      $.flower.data<repeat> = {}; # Initialize the repeat hash.
    }
    $xml.unset($tag);
    my @elements;
    my $count = 0;
    for @($array) -> $item {
      my $newxml = $xml.deep-clone;
      $.flower.data{$attrib} = $item;
      my $repeat = Flower::TAL::Repeat.new(:index($count), :length($array.elems));
      $.flower.data<repeat>{$attrib} = $repeat;
      my $wrapper = Exemel::Element.new(:nodes(($newxml)));
      $.flower.parse-elements($wrapper);
      @elements.push: @($wrapper.nodes);
      $count++;
    }
    $.flower.data<repeat>.delete($attrib);
    $.flower.data.delete($attrib);
    $xml = @elements;
  }
  else {
    $xml = Nil;
  }
}

method parse-omit ($xml is rw, $tag) {
  my $nodes = $xml.nodes;
  my $query = $xml.attribs{$tag};
  if $.tales.query($query, :bool) {
    $xml = $nodes;
  }
  else {
    $xml.unset: $tag;
  }
}
