#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings core since 5.6

use Test::More tests => 57;

BEGIN {
    use_ok "Text::CSV_XS";
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

{   my $csv = Text::CSV_XS->new ();

    is ($csv->meta_info, undef,				"meta_info () before parse ()");

    ok (1,						"parse () tests - No meta_info");
    ok (!$csv->parse (),				"Missing arguments");
    ok (!$csv->parse ('"abc'),				"Missing closing \"");
    ok (!$csv->parse ('ab"c'),				"\" outside of \"'s");
    ok (!$csv->parse ('"ab"c"'),			"Bad character sequence");
    ok (!$csv->parse (qq("abc\nc")),			"Bad character (NL)");
    ok (!$csv->status (),				"Wrong status ()");
    ok ( $csv->parse ('","'),				"comma - parse ()");
    is ( scalar $csv->fields (), 1,			"comma - fields () - count");
    is ( scalar $csv->meta_info (), 0,			"comma - meta_info () - count");
    is (($csv->fields ())[0], ",",			"comma - fields () - content");
    is (($csv->meta_info ())[0], undef,			"comma - meta_info () - content");
    ok ( $csv->parse (qq("","I said,\t""Hi!""","")),	"Hi! - parse ()");
    is ( scalar $csv->fields (), 3,			"Hi! - fields () - count");
    is ( scalar $csv->meta_info (), 0,			"Hi! - meta_info () - count");
    }

{   my $csv = Text::CSV_XS->new ({ keep_meta_info => 1 });

    ok (1,						"parse () tests - With flags");
    is ( $csv->meta_info, undef,			"meta_info before parse");

    ok (!$csv->parse (),				"Missing arguments");
    is ( $csv->meta_info, undef,			"meta_info after failing parse");
    ok (!$csv->parse ('"abc'),				"Missing closing \"");
    ok (!$csv->parse ('ab"c'),				"\" outside of \"'s");
    ok (!$csv->parse ('"ab"c"'),			"Bad character sequence");
    ok (!$csv->parse (qq("abc\nc")),			"Bad character (NL)");
    ok (!$csv->status (),				"Wrong status ()");
    ok ( $csv->parse ('","'),				"comma - parse ()");
    is ( scalar $csv->fields (), 1,			"comma - fields () - count");
    is ( scalar $csv->meta_info (), 1,			"comma - meta_info () - count");
    is (($csv->fields ())[0], ",",			"comma - fields () - content");
    is (($csv->meta_info ())[0], 1,			"comma - meta_info () - content");
    ok ( $csv->parse (qq("","I said,\t""Hi!""",)),	"Hi! - parse ()");
    is ( scalar $csv->fields (), 3,			"Hi! - fields () - count");
    is ( scalar $csv->meta_info (), 3,			"Hi! - meta_info () - count");

    is (($csv->fields ())[0], "",			"Hi! - fields () - field 1");
    is (($csv->meta_info ())[0], 1,			"Hi! - meta_info () - field 1");
    is (($csv->fields ())[1], qq(I said,\t"Hi!"),	"Hi! - fields () - field 2");
    is (($csv->meta_info ())[1], 1,			"Hi! - meta_info () - field 2");
    is (($csv->fields ())[2], "",			"Hi! - fields () - field 3");
    is (($csv->meta_info ())[2], 0,			"Hi! - meta_info () - field 3");

    }

{   my $csv = Text::CSV_XS->new ({ keep_meta_info => 1, binary => 1 });

    is ($csv->is_quoted (0), undef,		"is_quoted () before parse");
    is ($csv->is_binary (0), undef,		"is_binary () before parse");

    my $bintxt = chr ($] < 5.006 ? 0xbf : 0x20ac);
    ok ( $csv->parse (qq{,"1","a\rb",0,"a\nb",1,\x8e,"a\r\n","$bintxt","",}),
			"parse () - mixed quoted/binary");
    is (scalar $csv->fields, 11,		"fields () - count");
    my @fflg;
    ok (@fflg = $csv->meta_info,		"meta_info ()");
    is (scalar @fflg, 11,			"meta_info () - count");
    is_deeply ([ @fflg ], [ 0, 1, 3, 0, 3, 0, 2, 3, 3, 1, 0 ], "meta_info ()");

    is ($csv->is_quoted (0), 0,			"fflag 0 - not quoted");
    is ($csv->is_binary (0), 0,			"fflag 0 - not binary");
    is ($csv->is_quoted (2), 1,			"fflag 2 - quoted");
    is ($csv->is_binary (2), 1,			"fflag 2 - binary");

    is ($csv->is_quoted (6), 0,			"fflag 5 - not quoted");
    is ($csv->is_binary (6), 1,			"fflag 5 - binary");

    is ($csv->is_quoted (-1), undef,		"fflag -1 - undefined");
    is ($csv->is_binary (-8), undef,		"fflag -8 - undefined");

    is ($csv->is_quoted (21), undef,		"fflag 21 - undefined");
    is ($csv->is_binary (98), undef,		"fflag 98 - undefined");
    }
