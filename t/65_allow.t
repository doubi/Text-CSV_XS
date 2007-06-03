#!/usr/bin/perl

use strict;
$^W = 1;

#use Test::More "no_plan";
 use Test::More tests => 99;

BEGIN {
    use_ok "Text::CSV_XS", ();
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

my $csv;

ok (1, "Allow unescaped quotes");
# Allow unescaped quotes inside an unquoted field
{   my @bad = (
	# valid, line
	[ 1, qq{foo,bar,"baz",quux},					],
	[ 0, qq{rj,bs,r"jb"s,rjbs},					],
	[ 0, qq{some "spaced" quote data,2,3,4},			],
	[ 1, qq{and an,entirely,quoted,"field"},			],
	[ 1, qq{and then,"one with ""quoted"" quotes",okay,?},		],
	);

    for (@bad) {
	my ($valid, $bad) = @$_;
	$csv = Text::CSV_XS->new ();
	ok ($csv,			"new (alq => 0)");
	is ($csv->parse ($bad), $valid,	"parse () fail");

	$csv->allow_loose_quotes (1);
	ok ($csv->parse ($bad),		"parse () pass");
	ok (my @f = $csv->fields,	"fields");
	}
    }

ok (1, "Allow loose escapes");
# Allow escapes to escape characters that should not be escaped
{   my @bad = (
	# valid, line
	[ 1, qq{1,foo,bar,"baz",quux},					],
	[ 1, qq{2,escaped,"quote\\"s",in,"here"},			],
	[ 1, qq{3,escaped,quote\\"s,in,"here"},				],
	[ 1, qq{4,escap\\'d chars,allowed,in,unquoted,fields},		],
	[ 0, qq{5,42,"and it\\'s dog",},				],
	);

    for (@bad) {
	my ($valid, $bad) = @$_;
	$csv = Text::CSV_XS->new ({ escape_char => "\\" });
	ok ($csv,			"new (ale => 0)");
	is ($csv->parse ($bad), $valid,	"parse () fail");

	$csv->allow_loose_escapes (1);
	ok ($csv->parse ($bad),		"parse () pass");
	ok (my @f = $csv->fields,	"fields");
	}
    }

ok (1, "Allow whitespace");
# Allow whitespace to surround sep char
{   my @bad = (
	# valid, line
	[ 1, qq{1,foo,bar,baz,quux},					],
	[ 1, qq{1,foo,bar,"baz",quux},					],
	[ 1, qq{1, foo,bar,"baz",quux},					],
	[ 1, qq{ 1,foo,bar,"baz",quux},					],
	[ 0, qq{1,foo,bar, "baz",quux},					],
	[ 1, qq{1,foo ,bar,"baz",quux},					],
	[ 1, qq{1,foo,bar,"baz",quux },					],
	[ 1, qq{1,foo,bar,"baz","quux"},				],
	[ 0, qq{1,foo,bar,"baz" ,quux},					],
	[ 0, qq{1,foo,bar,"baz","quux" },				],
	[ 0, qq{ 1 , foo , bar , "baz" , quux },			],
	);

    for (@bad) {
	my ($valid, $bad) = @$_;
	$csv = Text::CSV_XS->new ();
	ok ($csv,			"new - '$bad')");
	is ($csv->parse ($bad), $valid,	"parse () fail");

	$csv->allow_whitespace (1);
	ok ($csv->parse ($bad),		"parse () pass");
	ok (my @f = $csv->fields,	"fields");

	local $" = ",";
	is ("@f", $bad[0][1],		"content");
	}
    }
