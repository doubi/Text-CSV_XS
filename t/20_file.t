#!/usr/bin/perl

use strict;
$^W = 1;	# use warnings;

use Test::More tests => 77;

BEGIN {
    use_ok "Text::CSV_XS";
    plan skip_all => "Cannot load Text::CSV_XS" if $@;
    }

############################################################################

package IO_Scalar;   # IO::Scalar replacement, because IO::Scalar is not
                     # yet a Core module.

use strict;
$^W = 1;	# use warnings;

sub new ($;\$)
{
    my ($proto, $strRef) = @_;
    my $self;
    if (!$strRef) {
	my $str = "";
	$self = \$str;
	}
    elsif (ref $strRef ne "SCALAR") {
	die "Expected scalar ref";
	}

    $self = \$$strRef;
    bless $self, ref ($proto) || $proto;
    $self;
    } # new

sub print ($@)
{
    my $self = shift;
    while (@_ > 0) {
	my $str = shift;
	defined $str and $$self .= $str;
	}
    1;
    } # print

sub getline ($)
{
    my $self = shift;
    my $result;
    my $ifs = $/;
    if (length ($$self) == 0) {
	$result = undef;
	}
    elsif (defined $ifs && $$self =~ /^(.*?$ifs)(.*)$/s) {
	$result = $1;
	$$self  = $2;
	}
    else {
	$result = $$self;
	$$self  = '';
	}
    $result;
    } # getline

sub sref ($)
{
    shift;
    } # sref

sub Contents ($)
{
    ${shift()->sref};
    } # Contents

sub flush ($)
{
    1;
    } # flush

############################################################################

package main;

use strict;
$^W = 1;	# use warnings;

sub TestContents ($$@)
{
    my ($csv, $fh, @input) = @_;
    my  $testname = pop @input;
    ok ($csv->combine (@input),	"parse ()");
    my ($got) = $fh->Contents();
    is ($csv->string (), $got,	"string ()");
    } # TestContents

sub TestPrintRead ($$@)
{
    my ($csv, @input) = @_;
    my $fh = IO_Scalar->new ();

    ok ($csv->print ($fh, \@input),		"print on IO::Scalar");
    TestContents ($csv, $fh, @input,		"TestPrintRead");
    ok ($csv->getline ($fh),			"getline () on IO::Scalar");
    is ($csv->fields (), scalar @input,		"field count");
    for (0 .. $#input) {
	is (($csv->fields ())[$_], $input[$_],	"field $_");
	}
    } # TestPrintRead

sub TestReadFailure ($$)
{
    my ($csv, $input) = @_;
    my $fh = IO_Scalar->new ();
    unless ($fh->print ($input) && $fh->flush ()) {
	die "Error while creating input file: $!";
	}
    
    ok (!$csv->getline ($fh), "getline");
    } # TestReadFailure

sub TestRead ($$@)
{
    my ($csv, $input, @expected) = @_;
    my $fh = IO_Scalar->new ();
    unless ($fh->print ($input) && $fh->flush ()) {
	die "Error while creating input file: $!";
	}

    my $fields = $csv->getline ($fh);
    ok ($fields,	"getline");
    is (scalar @expected, scalar @$fields, "field count");
    for (0 .. $#expected) {
	is ($expected[$_], $$fields[$_], "field $_");
	}
    } # TestRead

my $csv = Text::CSV_XS->new ();
my $fh  = IO_Scalar->new ();

ok (!$csv->print ($fh, ["abc", "def\007", "ghi"]), "print bad character");
TestPrintRead ($csv, q(""));
TestPrintRead ($csv, '', '');
TestPrintRead ($csv, '', 'I said, "Hi!"', '');
TestPrintRead ($csv, '"', 'abc');
TestPrintRead ($csv, 'abc', '"');
TestPrintRead ($csv, 'abc', 'def', 'ghi');
TestPrintRead ($csv, "abc\tdef", 'ghi');
TestReadFailure ($csv, '"abc')
    or print("Missing closing double-quote, but no failure\n");
TestReadFailure ($csv, 'ab"c')
    or print("Double quote outside of double-quotes, but no failure.\n");
TestReadFailure ($csv, '"ab"c"')
    or print("Bad character sequence, but no failure.\n");
TestReadFailure ($csv, qq("abc\nc"))
    or print("Bad character, but no failure.\n");
TestRead ($csv, q(","), ',');
TestRead ($csv, qq("","I said,\t""Hi!""",""),
	 '', qq(I said,\t"Hi!"), '');

# This test because of a problem with DBD::CSV

$fh = IO_Scalar->new ();
$csv->binary (1);
$csv->eol    ("\015\012");
ok ($csv->print ($fh, ["id","name"]),			"Bad character");
ok ($csv->print ($fh, [1, "Alligator Descartes"]),	"Name 1");
ok ($csv->print ($fh, ["3", "Jochen Wiedmann"]),	"Name 2");
ok ($csv->print ($fh, [2, "Tim Bunce"]),		"Name 3");
ok ($csv->print ($fh, [" 4", "Andreas König"]),		"Name 4");
ok ($csv->print ($fh, [5]),				"Name 5");
my $expected = <<"CONTENTS";
id,name\015
1,"Alligator Descartes"\015
3,"Jochen Wiedmann"\015
2,"Tim Bunce"\015
" 4","Andreas König"\015
5\015
CONTENTS
is ($fh->Contents (), $expected,			"Content");

my $fields;
print "# Retrieving data\n";
for (0 .. 5) {
    ok ($fields = $csv->getline ($fh),			"Fetch field $_");
    print "# Row $_: $fields (@$fields)\n";
    }
