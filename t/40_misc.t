#!/usr/bin/perl

use strict;
$^W = 1;

use Test::More tests => 21;

BEGIN {
    require_ok "Text::CSV_XS";
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

sub is_binary ($$$)
{
    my ($str, $exp, $tst) = @_;
    if ($str eq $exp) {
	ok (1,		$tst);
	}
    else {
	my ($hs, $he) = map { unpack "H*", $_ } $str, $exp;
	is ($hs, $he,	$tst);
	}
    } # is_binary

$| = 1;

my @binField = ("abc\0def\n\rghi", "ab\"ce,\032\"'", "\377");

my $csv = Text::CSV_XS->new ({ binary => 1 });
ok ($csv->combine (@binField),					"combine ()");

my $string;
is_binary ($string = $csv->string,
	   qq("abc"0def\n\rghi","ab""ce,\032""'",\377),		"string ()");

ok ($csv->parse ($string),					"parse ()");
is ($csv->fields, scalar @binField,				"field count");

my @field = $csv->fields ();
for (0 .. $#binField) {
    is ($field[$_], $binField[$_],				"Field $_");
    }

ok (1,								"eol \\r\\n");
$csv->eol ("\r\n");
ok ($csv->combine (@binField),					"combine ()");
is_binary ($csv->string,
	   qq("abc"0def\n\rghi","ab""ce,\032""'",\377\r\n),	"string ()");

ok (1,								"eol \\n");
$csv->eol ("\n");
ok ($csv->combine (@binField),					"combine ()");
is_binary ($csv->string,
	   qq("abc"0def\n\rghi","ab""ce,\032""'",\377\n),	"string ()");

ok (1,								"quote_char undef");
$csv->quote_char (undef);
ok ($csv->combine ("abc","def","ghi"),				"combine");
is ($csv->string, "abc,def,ghi\n",				"string ()");

# Ken's test
ok (1,								"always_quote");
my $csv2 = Text::CSV_XS->new ({ always_quote => 1 });
ok ($csv2,							"new ()");
ok ($csv2->combine ("abc","def","ghi"),				"combine ()");
is ($csv2->string, '"abc","def","ghi"',				"string ()");
