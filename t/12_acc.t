#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings core since 5.6

use Test::More tests => 19;

BEGIN {
    use_ok "Text::CSV_XS";
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

my $csv;
ok ($csv = Text::CSV_XS->new,				"new ()");

is ($csv->quote_char,		'"',			"quote_char");
is ($csv->escape_char,		'"',			"escape_char");
is ($csv->sep_char,		',',			"sep_char");
is ($csv->eol,			'',			"eol");
is ($csv->always_quote,		0,			"always_quote");
is ($csv->binary,		0,			"binary");
is ($csv->keep_meta_info,	0,			"binary");

is ($csv->binary (1),		1,			"binary (1)");
my @fld = ( 'txt =, "Hi!"', "Yes", "", 2, undef, "1.09", "\r", undef );
ok ($csv->combine (@fld),				"combine");
is ($csv->string,
    qq{"txt =, ""Hi!""",Yes,,2,,1.09,"\r",},	"string");

is ($csv->sep_char (";"),	';',			"sep_char (;)");
is ($csv->quote_char ("="),	'=',			"quote_char (=)");
is ($csv->keep_meta_info (1),	1,			"keep_meta_info (1)");
is ($csv->always_quote (1),	1,			"always_quote (1)");
is ($csv->escape_char ("\\"),	"\\",			"escape_char (\\)");
ok ($csv->combine (@fld),				"combine");
is ($csv->string,
    qq{=txt \\=, "Hi!"=;=Yes=;==;=2=;;=1.09=;=\r=;},	"string");
