#!/usr/bin/perl -w

require 5.005;
use strict;

require Text::CSV_XS;
require Benchmark;

my @fields = (
    "Wiedmann", "Jochen",
    "Am Eisteich 9",
    "72555 Metzingen",
    "Germany",
    "+49 7123 14881",
    "joe\@ispsoft,de");

my ($count, $csv) = (1_000_000, Text::CSV_XS->new);

print "Testing row creation speed ...\n";
my $t1 = Benchmark->new;
for (1 .. $count) {
    $csv->combine (@fields);
    }
my $td  = Benchmark::timediff (Benchmark->new, $t1);
my $dur = $td->cpu_a;
printf "$count rows created in %5.2f cpu+sys seconds (%8d per sec)\n\n",
   $dur, $count / $dur;

print "Testing row parsing speed (short string) ...\n";
my $str = $csv->string;
$t1 = Benchmark->new;
for (1 .. $count) {
    $csv->parse ($str);
    }
$td  = Benchmark::timediff (Benchmark->new, $t1);
$dur = $td->cpu_a;
printf "$count rows parsed  in %5.2f cpu+sys seconds (%8d per sec)\n\n",
   $dur, $count / $dur;

print "Testing row parsing speed (long string) ...\n";
$str = join ",", ($str) x 100;
my $lcount = $count / 100;
$t1 = Benchmark->new;
for (1 .. $lcount) {
    $csv->parse ($str);
    }
$td  = Benchmark::timediff (Benchmark->new, $t1);
$dur = $td->cpu_a;
printf "  $lcount rows parsed  in %5.2f cpu+sys seconds (%8d per sec)\n\n",
   $dur, $lcount / $dur;


# The examples from the docs

{ my $csv = Text::CSV_XS->new ({ keep_meta_info => 1, binary => 1 });

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
