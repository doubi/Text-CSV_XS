#!/usr/bin/perl -w

require 5.005;
use strict;

use IO::Handle;
use Text::CSV_XS;
use Benchmark qw(:all);

my $csv = Text::CSV_XS->new ({ eol => "\n" });

my $bigfile = "_file.csv";
my @fields1 = (
    "Wiedmann", "Jochen",
    "Am Eisteich 9",
    "72555 Metzingen",
    "Germany",
    "+49 7123 14881",
    "joe\@ispsoft,de");
my @fields10  = (@fields1) x 10;
my @fields100 = (@fields1) x 100;

$csv->combine (@fields1  ); my $str1   = $csv->string;
$csv->combine (@fields10 ); my $str10  = $csv->string;
$csv->combine (@fields100); my $str100 = $csv->string;

timethese (-10, {

    "combine   1"	=> sub { $csv->combine (@fields1  ) },
    "combine  10"	=> sub { $csv->combine (@fields10 ) },
    "combine 100"	=> sub { $csv->combine (@fields100) },

    "parse     1"	=> sub { $csv->parse   ($str1     ) },
    "parse    10"	=> sub { $csv->parse   ($str10    ) },
    "parse   100"	=> sub { $csv->parse   ($str100   ) },

    });

open my $io, ">", $bigfile;
$csv->print ($io, \@fields10) or die "Cannot print ()\n";
timethese (500_000, { "print    io" => sub { $csv->print ($io, \@fields10) }});
close   $io;
-s $bigfile or die "File is empty!\n";
open    $io, "<", $bigfile;
timethese (500_000, { "getline  io" => sub { my $ref = $csv->getline ($io) }});
close   $io;
print "File was ", -s $bigfile, " bytes long, line length ", length ($str10), "\n";
unlink $bigfile;

__END__
# The examples from the docs

{ $csv = Text::CSV_XS->new ({ keep_meta_info => 1, binary => 1 });

  my $sample_input_string =
      qq{"I said, ""Hi!""",Yes,"",2.34,,"1.09","\x{20ac}",};
  if ($csv->parse ($sample_input_string)) {
      my @field = $csv->fields;
      foreach my $col (0 .. $#field) {
          my $quo = $csv->is_quoted ($col) ? $csv->{quote_char} : "";
          printf "%2d: %s%s%s\n", $col, $quo, $field[$col], $quo;
          }
      }
  else {
      my $err = $csv->error_input;
      print "parse () failed on argument: ", $err, "\n";
      }
  }
