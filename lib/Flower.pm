class Flower;

use Exemel;

has $.template;

has $!petal is rw = 'petal';
has $!metal is rw = 'metal';
has $!i18n is rw  = 'i18n';

has $!petal-ns = 'http://purl.org/petal/1.0/';
has $!metal-ns = 'http://xml.zope.org/namespaces/metal';
has $!i18n-ns  = 'http://xml.zope.org/namespaces/i18n';

has @!petal-tags = 'define', 'condition', 'repeat', 'attributes', 'content', 'replace', 'omit-tag';

has @!metal-tags = 'define-macro', 'use-macro', 'define-slot', 'fill-slot';

## Override find with a subroutine that can find templates based off
## of whatever your needs are (multiple roots, extensions, etc.)
has $!find;

method new (:$find is copy, :$file, :$template is copy) {
  if ( ! $file && ! $template ) { die "a file or template must be specified."; }
  if ! $find {
    $find = sub ($file) {
      if $file.IO ~~ :f { return $file; }
    }
  }
  if $file {
    my $filename = $find($file);
    $template = Exemel::Document.parse(slurp($filename));
  }
  else {
    if $template ~~ Exemel::Document {
      1; # we don't need to do anything.
    }
    elsif $template ~~ Exemel::Element {
      $template = Exemel::Document.new(:root($template));
    }
    elsif $template ~~ Str {
      $template = Exemel::Document.parse($template);
    }
    else {
      die "invalid template type passed.";
    }
  }
  self.bless(*, :$template, :$find);
}

method !xml-ns ($ns is copy) {
  $ns ~~ s/^xmlns\://;
  return $ns;
}

## Note: Once you have parsed, the template will forever be changed.
## You can't parse twice, so don't fark it up!
## You can access the template Exemel::Document object by using the
## $flower.template attribute.
method parse (*%data) {
  ## First, let's see if the namespaces have been renamed.
  for $.template.root.attribs.kv -> $key, $val {
    if $val eq $!petal-ns {
      $!petal = self!xml-ns($key);
    }
    elsif $val eq $!metal-ns {
      $!metal = self!xml-ns($key);
    }
    elsif $val eq $!i18n-ns {
      $!i18n = self!xml-ns($key);
    }
  }
  ## Okay, now let's parse the elements.
  self!parse-elements(%data, $.template.root);
  return ~$.template;
}

## parse-elements, currently only does petal items.
## metal will be added in the next major release.
## i18n will be added at some point in the future.
## also TODO: implement 'on-error'.
method !parse-elements (%data, $xml is rw) {
  ## Due to the strange nature of some rules, we're not using the
  ## 'elements' helper, nor using a nice 'for' loop. Instead we're doing this
  ## by hand. It'll all make sense.
  loop (my $i=0; True; $i++) {
    if $i == $xml.nodes.elems { last; }
    my $element = $xml.nodes[$i];
    if $element !~~ Exemel::Element { next; } # skip non-elements.
    for @!petal-tags -> $petal {
      my $tag = $!petal~':'~$petal;
      self!parse-tag(%data, $element, $tag, $petal);
      if $element !~~ Exemel::Element { last; } # skip if we changed type.
    }
#    for @metal -> $metal {
#      my $tag = $!metal~':'~$metal;
#      self!parse-tag(%data, $element, $tag, $metal);
#    }
    ## Now we clean up removed elements, and insert replacements.
    if ! defined $element {
      $xml.nodes.splice($i--, 1);
    }
    elsif $element ~~ Array {
      $xml.nodes.splice($i--, 1, |$element);
    }
    else {
      if $element ~~ Exemel::Element {
        self!parse-elements(%data, $element);
      }
      $xml.nodes[$i] = $element; # Ensure the node is updated.
    }
  }
}

method !parse-tag (%data, $element is rw, $tag, $ns) {
  my $method = 'parse-'~$ns;
  if $element.attribs.exists($tag) {
    self!"$method"(%data, $element, $tag);
  }
}

method !parse-define (%data, $xml is rw, $tag) {
  my ($attrib, $query) = $xml.attribs{$tag}.split(/\s+/, 2);
  my $val = self!query(%data, $query);
  if defined $val { %data{$attrib} = $val; }
  $xml.unset($tag);
}

method !parse-condition (%data, $xml is rw, $tag) { ... }

method !parse-content (%data, $xml is rw, $tag) {
  $xml.nodes.splice;
  $xml.nodes.push: self!query(%data, $xml.attribs{$tag});
  $xml.unset: $tag;
}

method !parse-replace (%data, $xml is rw, $tag) {
  my $text = $xml.attribs{$tag};
  $xml = Exemel::Text.new(:text(self!query(%data, $text)));
}

method !parse-repeat (%data, $xml is rw, $tag) { ... }

method !parse-omit-tag (%data, $xml is rw, $tag) { ... }

## This is a stub, expand it into a proper method.
method !query (%data, $query) {
  if %data.exists($query) { return %data{$query} }
  return;
}

