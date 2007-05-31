package Text::CSV_XS;

# Copyright (c) 2007-2007 H.Merijn Brand.  All rights reserved.
# Copyright (c) 1998-2001 Jochen Wiedmann. All rights reserved.
# Portions Copyright (c) 1997 Alan Citterman. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

################################################################################
# HISTORY
#
# Written by:
#    Jochen Wiedmann <joe@ispsoft.de>
#
# Based on Text::CSV by:
#    Alan Citterman <alan@mfgrtl.com>
#
# Extended by:
#    H.Merijn Brand (h.m.brand@xs4all.nl)
#
############################################################################

require 5.005;

use strict;

use DynaLoader ();

use vars   qw( $VERSION @ISA );
$VERSION = "0.27";
@ISA     = qw( DynaLoader );

sub PV () { 0 }
sub IV () { 1 }
sub NV () { 2 }

# version
#
#   class/object method expecting no arguments and returning the version
#   number of Text::CSV.  there are no side-effects.

sub version
{
    return $VERSION;
    } # version

# new
#
#   class/object method expecting no arguments and returning a reference to
#   a newly created Text::CSV object.

sub new ($;$)
{
    my $proto = shift;
    my $attr  = shift || {};
    my $class = ref ($proto) || $proto;
    my $self  = {
	quote_char	=> '"',
	escape_char	=> '"',
	sep_char	=> ',',
	eol		=> '',
	always_quote	=> 0,
	binary		=> 0,
	keep_meta_info	=> 0,

	_STATUS		=> undef,
	_FIELDS		=> undef,
	_FFLAGS		=> undef,
	_STRING		=> undef,
	_ERROR_INPUT	=> undef,

	%$attr,
	};
    bless $self, $class;
    exists $self->{types} and $self->types ($self->{types});
    $self;
    } # new

# Accessor methods.
#   It is unwise to change them halfway through a single file!
sub quote_char ($;$)
{
    my $self = shift;
    @_ and $self->{quote_char} = shift;
    $self->{quote_char};
    } # quote_char

sub escape_char ($;$)
{
    my $self = shift;
    @_ and $self->{escape_char} = shift;
    $self->{escape_char};
    } # escape_char

sub sep_char ($;$)
{
    my $self = shift;
    @_ and $self->{sep_char} = shift;
    $self->{sep_char};
    } # sep_char

sub eol ($;$)
{
    my $self = shift;
    @_ and $self->{eol} = shift;
    $self->{eol};
    } # eol

sub always_quote ($;$)
{
    my $self = shift;
    @_ and $self->{always_quote} = shift;
    $self->{always_quote};
    } # always_quote

sub binary ($;$)
{
    my $self = shift;
    @_ and $self->{binary} = shift;
    $self->{binary};
    } # binary

sub keep_meta_info ($;$)
{
    my $self = shift;
    @_ and $self->{keep_meta_info} = shift;
    $self->{keep_meta_info};
    } # keep_meta_info

# status
#
#   object method returning the success or failure of the most recent
#   combine () or parse ().  there are no side-effects.

sub status ($)
{
    my $self = shift;
    return $self->{_STATUS};
    } # status

# error_input
#
#   object method returning the first invalid argument to the most recent
#   combine () or parse ().  there are no side-effects.

sub error_input ($)
{
    my $self = shift;
    return $self->{_ERROR_INPUT};
    } # error_input

# string
#
#   object method returning the result of the most recent combine () or the
#   input to the most recent parse (), whichever is more recent.  there are
#   no side-effects.

sub string ($)
{
    my $self = shift;
    return $self->{_STRING};
    } # string

# fields
#
#   object method returning the result of the most recent parse () or the
#   input to the most recent combine (), whichever is more recent.  there
#   are no side-effects.

sub fields ($)
{
    my $self = shift;
    return ref $self->{_FIELDS} ? @{$self->{_FIELDS}} : undef;
    } # fields

# meta_info
#
#   object method returning the result of the most recent parse () or the
#   input to the most recent combine (), whichever is more recent.  there
#   are no side-effects. meta_info () returns (if available)  some of the
#   field's properties

sub meta_info ($)
{
    my $self = shift;
    return ref $self->{_FFLAGS} ? @{$self->{_FFLAGS}} : undef;
    } # meta_info

sub is_quoted ($$;$)
{
    my ($self, $idx, $val) = @_;
    ref $self->{_FFLAGS} &&
	$idx >= 0 && $idx < @{$self->{_FFLAGS}} or return;
    $self->{_FFLAGS}[$idx] & 0x0001 ? 1 : 0;
    } # is_quoted

sub is_binary ($$;$)
{
    my ($self, $idx, $val) = @_;
    ref $self->{_FFLAGS} &&
	$idx >= 0 && $idx < @{$self->{_FFLAGS}} or return;
    $self->{_FFLAGS}[$idx] & 0x0002 ? 1 : 0;
    } # is_binary

# combine
#
#   object method returning success or failure.  the given arguments are
#   combined into a single comma-separated value.  failure can be the
#   result of no arguments or an argument containing an invalid character.
#   side-effects include:
#      setting status ()
#      setting fields ()
#      setting string ()
#      setting error_input ()

sub combine ($@)
{
    my ($self, @part) = @_;
    my $str  = "";
    my $ref  = \$str;
    $self->{_FIELDS}      = \@part;
    $self->{_FFLAGS}      = undef;
    $self->{_ERROR_INPUT} = undef;
    $self->{_STATUS}      =
	(@part > 0) && $self->Combine (\$str, \@part, 0, $self->{eol});
    $self->{_STRING}      = $str;
    $self->{_STATUS};
    } # combine

# parse
#
#   object method returning success or failure.  the given argument is
#   expected to be a valid comma-separated value.  failure can be the
#   result of no arguments or an argument containing an invalid sequence
#   of characters. side-effects include:
#      setting status ()
#      setting fields ()
#      setting meta_info ()
#      setting string ()
#      setting error_input ()

sub parse ($$)
{
    my ($self, $str) = @_;

    my $fields = [];
    my $fflags = [];
    $self->{_STRING} = $self->{ERROR_INPUT} = $str;
    $self->{_STATUS} = 0;
    $self->{_FIELDS} = undef;
    $self->{_FFLAGS} = undef;
    if (defined $str  && $self->Parse ($str, $fields, $fflags, 0)) {
	$self->{_FIELDS} = $fields;
	$self->{_FFLAGS} = $fflags;
	$self->{_STATUS} = 1;
	}
    $self->{_STATUS};
    } # parse

bootstrap Text::CSV_XS $VERSION;

sub types
{
    my $self = shift;
    if (@_) {
	if (my $types = shift) {
	    $self->{_types} = join "", map { chr $_ } @$types;
	    $self->{types}  = $types;
	    }
	else {
	    delete $self->{types};
	    delete $self->{_types};
	    undef;
	    }
	}
    else {
	$self->{types};
	}
    } # types

1;

__END__

=head1 NAME

Text::CSV_XS - comma-separated values manipulation routines

=head1 SYNOPSIS

 use Text::CSV_XS;

 $csv = Text::CSV_XS->new ();          # create a new object
 $csv = Text::CSV_XS->new (\%attr);    # create a new object

 $status  = $csv->combine (@columns);  # combine columns into a string
 $line    = $csv->string ();           # get the combined string

 $status  = $csv->parse ($line);       # parse a CSV string into fields
 @columns = $csv->fields ();           # get the parsed fields

 $status       = $csv->status ();      # get the most recent status
 $bad_argument = $csv->error_input (); # get the most recent bad argument

 $status = $csv->print ($io, $colref); # Write an array of fields
                                       # immediately to a file $io
 $colref = $csv->getline ($io);        # Read a line from file $io,
                                       # parse it and return an array
                                       # ref of fields

 $csv->types (\@t_array);              # Set column types

=head1 DESCRIPTION

Text::CSV_XS provides facilities for the composition and decomposition of
comma-separated values.  An instance of the Text::CSV_XS class can combine
fields into a CSV string and parse a CSV string into fields.

The module accepts either strings or files as input and can utilize any
user-specified characters as delimiters, separators, and escapes so it is
perhaps better called ASV (anything separated values) rather than just CSV.

=head2 Embedded newlines

B<Important Note>: The default behaviour is to only accept ascii characters.
This means that fields can not contain newlines. If your data contains 
newlines embedded in fields, or characters above 0x7e (tilde), or binary data,
you *must* set C<binary => 1> in the call to C<new ()>.  To cover the widest
range of parsing options, you will always want to set binary.

But you still have the problem that you have to pass a correct line to the
C<parse ()> method, which is more complicated from the usual point of
usage:

 my $csv = Text::CSV_XS->new ({ binary => 1, eol => $/ });
 while (<>) {
     $csv->parse ($_);
     my @fields = $csv->fields ();

will break, as the while might read broken lines, as that doesn't care
about the quoting. If you need to support embedd newlines, the way to go
is either

 use IO::Handle;
 my $csv = Text::CSV_XS->new ({ binary => 1, eol => $/ });
 while (my $row = $csv->getline (*ARGV)) {
     my @fields = @$row;

or, more safely in perl 5.6 and up

 my $csv = Text::CSV_XS->new ({ binary => 1, eol => $/ });
 open my $io, "<", $file or die "$file: $!";
 while (my $row = $csv->getline ($io)) {
     my @fields = @$row;
 
=head1 FUNCTIONS

=over 4

=item version ()

(Class method) Returns the current module version.

=item new (\%attr)

(Class method) Returns a new instance of Text::CSV_XS. The objects
attributes are described by the (optional) hash ref C<\%attr>.
Currently the following attributes are available:

=over 4

=item quote_char

The char used for quoting fields containing blanks, by default the
double quote character (C<">). A value of undef suppresses
quote chars. (For simple cases only).

The quote character can not be equal to the separation character.

=item eol

An end-of-line string to add to rows, usually C<undef> (nothing,
default), C<"\012"> (Line Feed) or C<"\015\012"> (Carriage Return,
Line Feed)

If both C<$/> and C<eol> equal C<"\015">, parsing lines that end on
only a Carriage Return without Line Feed, will be C<parse>d correct.
Line endings, wheather in C<$/> or C<eol>, other than C<undef>,
C<"\n">, C<"\r\n">, or C<"\r"> are not (yet) supported for parsing.

=item escape_char

The character used for escaping certain characters inside quoted fields.

The C<escape_char> defaults to being the literal double-quote mark (C<">)
in other words, the same as the default C<quote_char>. This means that
doubling the quote mark in a field escapes it:

  "foo","bar","Escape ""quote mark"" with two ""quote marks""","baz"

If you change the default quote_char without changing the default
escape_char, the escape_char will still be the quote mark.  If instead 
you want to escape the quote_char by doubling it, you will need to change
the escape_char to be the same as what you changed the quote_char to.

The escape character can not be equal to the separation character.

=item sep_char

The char used for separating fields, by default a comma. (C<,>)

The separation character can not be equal to the quote character.
The separation character can not be equal to the escape character.

=item binary

If this attribute is TRUE, you may use binary characters in quoted fields,
including line feeds, carriage returns and NULL bytes. (The latter must
be escaped as C<"0>.) By default this feature is off.

=item types

A set of column types; this attribute is immediately passed to the
I<types> method below. You must not set this attribute otherwise,
except for using the I<types> method. For details see the description
of the I<types> method below.

=item always_quote

By default the generated fields are quoted only, if they need to, for
example, if they contain the separator. If you set this attribute to
a TRUE value, then all fields will be quoted. This is typically easier
to handle in external applications. (Poor creatures who aren't using
Text::CSV_XS. :-)

=item keep_meta_info

By default, the parsing of input lines is as simple and fast as
possible. However, some parsing information - like quotation of
the original field - is lost in that process. Set this flag to
true to be able to retrieve that information after parsing with
the methods C<meta_info ()>, C<is_quoted ()>, and C<is_binary ()>
described below.  Default is false.

=back

To sum it up,

 $csv = Text::CSV_XS->new ();

is equivalent to

 $csv = Text::CSV_XS->new ({
     quote_char     => '"',
     escape_char    => '"',
     sep_char       => ',',
     eol            => '',
     always_quote   => 0,
     binary         => 0,
     keep_meta_info => 0,
     });

For all of the above mentioned flags, there is an accessor method
available where you can inquire for the current value, or change
the value

 my $quote = $csv->quote_char;
 $csv->binary (1);

It is unwise to change these settings halfway through writing CSV
data to a stream. If however, you want to create a new stream using
the available CSV object, there is no harm in changing them.

=item combine

 $status = $csv->combine (@columns);

This object function constructs a CSV string from the arguments, returning
success or failure.  Failure can result from lack of arguments or an argument
containing an invalid character.  Upon success, C<string ()> can be called to
retrieve the resultant CSV string.  Upon failure, the value returned by
C<string ()> is undefined and C<error_input ()> can be called to retrieve an
invalid argument.

=item print

 $status = $csv->print ($io, $colref);

Similar to combine, but it expects an array ref as input (not an array!)
and the resulting string is not really created, but immediately written
to the I<$io> object, typically an IO handle or any other object that
offers a I<print> method. Note, this implies that the following is wrong:

 open FILE, ">", "whatever";
 $status = $csv->print (\*FILE, $colref);

The glob C<\*FILE> is not an object, thus it doesn't have a print
method. The solution is to use an IO::File object or to hide the
glob behind an IO::Wrap object. See L<IO::File(3)> and L<IO::Wrap(3)>
for details.

For performance reasons the print method doesn't create a result string.
In particular the I<$csv-E<gt>string ()>, I<$csv-E<gt>status ()>,
I<$csv->fields ()> and I<$csv-E<gt>error_input ()> methods are meaningless
after executing this method.

=item string

 $line = $csv->string ();

This object function returns the input to C<parse ()> or the resultant CSV
string of C<combine ()>, whichever was called more recently.

=item parse

 $status = $csv->parse ($line);

This object function decomposes a CSV string into fields, returning
success or failure.  Failure can result from a lack of argument or the
given CSV string is improperly formatted.  Upon success, C<fields ()> can
be called to retrieve the decomposed fields .  Upon failure, the value
returned by C<fields ()> is undefined and C<error_input ()> can be called
to retrieve the invalid argument.

You may use the I<types ()> method for setting column types. See the
description below.

=item getline

 $colref = $csv->getline ($io);

This is the counterpart to print, like parse is the counterpart to
combine: It reads a row from the IO object $io using $io->getline ()
and parses this row into an array ref. This array ref is returned
by the function or undef for failure.

The I<$csv-E<gt>string ()>, I<$csv-E<gt>fields ()> and I<$csv-E<gt>status ()>
methods are meaningless, again.

=item types

 $csv->types (\@tref);

This method is used to force that columns are of a given type. For
example, if you have an integer column, two double columns and a
string column, then you might do a

 $csv->types ([Text::CSV_XS::IV (),
               Text::CSV_XS::NV (),
               Text::CSV_XS::NV (),
               Text::CSV_XS::PV ()]);

Column types are used only for decoding columns, in other words
by the I<parse ()> and I<getline ()> methods.

You can unset column types by doing a

 $csv->types (undef);

or fetch the current type settings with

 $types = $csv->types ();

=over 4

=item IV

Set field type to integer.

=item NV

Set field type to numeric/float.

=item PV

Set field type to string.

=back

=item fields

 @columns = $csv->fields ();

This object function returns the input to C<combine ()> or the resultant
decomposed fields of C<parse ()>, whichever was called more recently.

=item meta_info

 @flags = $csv->meta_info ();

This object function returns the flags of the input to C<combine ()> or
the flags of the resultant decomposed fields of C<parse ()>, whichever
was called more recently.

For each field, a meta_info field will hold flags that tell something about
the field returned by the C<fields ()> method or passed to the C<combine ()>
method. The flags are bitwise-or'd like:

=over 4

=item 0x0001

The field was quoted.

=item 0x0002

The field was binary.

=back

See the C<is_*** ()> methods below.

=item is_quoted

  my $quoted = $csv->is_quoted ($column_idx);

Where C<$column_idx> is the (zero-based) index of the column in the
last result of C<parse ()>.

This returns a true value if the data in the indicated column was
enclosed in C<quote_char> quotes. This might be important for data
where C<,20070108,> is to be treated as a numeric value, and where
C<,"20070108",> is explicitly marked as character string data.

=item is_binary

  my $binary = $csv->is_binary ($column_idx);

Where C<$column_idx> is the (zero-based) index of the column in the
last result of C<parse ()>.

This returns a true value if the data in the indicated column
contained any byte in the range [\x00-\x08,\x10-\x1F,\x7F-\xFF]

=item status

 $status = $csv->status ();

This object function returns success (or failure) of C<combine ()> or
C<parse ()>, whichever was called more recently.

=item error_input

 $bad_argument = $csv->error_input ();

This object function returns the erroneous argument (if it exists) of
C<combine ()> or C<parse ()>, whichever was called more recently.

=back

=head1 INTERNALS

=over 4

=item Combine (...)

=item Parse (...)

=back

The arguments to these two internal functions are deliberately not
described or documented to enable the module author(s) to change it
when they feel the need for it and using them is highly discouraged
as the API may change in future releases.

=head1 EXAMPLES

An example for creating CSV files:

  use Text::CSV_XS;

  my $csv = Text::CSV_XS->new;

  open my $csv_fh, ">", "hello.csv" or die "hello.csv: $!";

  my @sample_input_fields = (
      'You said, "Hello!"',   5.67,
      '"Surely"',   '',   '3.14159');
  if ($csv->combine (@sample_input_fields)) {
      my $string = $csv->string;
      print $csv_fh "$string\n";
      }
  else {
      my $err = $csv->error_input;
      print "combine () failed on argument: ", $err, "\n";
      }
  close $csv_fh;

An example for parsing CSV lines:

  use Text::CSV_XS;

  my $csv = Text::CSV_XS->new ({ keep_meta_info => 1, binary => 1 });

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

=head1 CAVEATS

This module is based upon a working definition of CSV format which may not be
the most general.

=over 4

=item 1

Allowable characters within a CSV field include 0x09 (tab) and the inclusive
range of 0x20 (space) through 0x7E (tilde). In binary mode all characters
are accepted, at least in quoted fields:

=item 2

A field within CSV may be surrounded by double-quotes. (The quote char)

=item 3

A field within CSV must be surrounded by double-quotes to contain a comma.
(The separator char)

=item 4

A field within CSV must be surrounded by double-quotes to contain an embedded
double-quote, represented by a pair of consecutive double-quotes. In binary
mode you may additionally use the sequence C<"0> for representation of a
NULL byte.

=item 5

A CSV string may be terminated by 0x0A (line feed) or by 0x0D,0x0A
(carriage return, line feed).

=back

=head1 TODO

=over 2

=item eol

Discuss an option to make the eol honor the $/ setting. Maybe

  my $csv = Text::CSV_XS->new ({ eol => $/ });

is already enough, and new options only make things less opaque.

=item setting meta info

Future extensions might include extending the C<fields_flags ()>,
C<is_quoted ()>, and C<is_binary ()> to accept setting these flags
for fields, so you can specify which fields are quoted in the
combine ()/string () combination.

  $csv->meta_info (0, 1, 1, 3, 0, 0);
  $csv->is_quoted (3, 1);

=item parse returning undefined fields

Adding an option that enables the parser to distinguish between
empty fields and undefined fields, like

  $csv->quote_always (1);
  $csv->allow_undef (1);
  $csv->parse (qq{,"",1,"2",,""});
  my @fld = $csv->fields ();

Then would return (undef, "", "1", "2", undef, "") in @fld, instead
of the current ("", "", "1", "2", "", "").

=item combined methods

Adding means (methods) that combine C<combine ()> and C<string ()> in
a single call. Likewise for C<parse ()> and C<fields ()>. Given the
trouble with embedded newlines, maybe just allowing C<getline ()> and
C<print ()> is sufficient.

=item Unicode

Make C<parse ()> and C<combine ()> do the right thing for Unicode
(UTF-8) if requested. See t/50_utf8.t. More complicated, but evenly
important, also for C<getline ()> and C<print ()>.

=item Space delimited seperators

Discuss if and how C<Text::CSV_XS> should/could support formats like

   1 , "foo" , "bar" , 3.19 ,

=item Double double quotes

There seem to be applications around that write their dates like

   1,4,""12/11/2004"",4,1

If we would support that, in what way?

=item Parse the whole file at once

Implement a new methods that enables the parsing of a complete file
at once, returning a lis of hashes. Possible extension to this could
be to enable a column selection on the call:

   my @AoH = $csv->parse_file ($filename, { cols => [ 1, 4..8, 12 ]});

Returning something like

   [ { fields => [ 1, 2, "foo", 4.5, undef, "", 8 ],
       flags  => [ ... ],
       errors => [ ... ],
       },
     { fields => [ ... ],
       .
       .
       },
     ]

=back

=head1 SEE ALSO

L<perl(1)>, L<IO::File(3)>, L<IO::Wrap(3)>, L<Spreadsheet::Read(3)>

=head1 AUTHORS and MAINTAINERS

Alan Citterman F<E<lt>alan@mfgrtl.comE<gt>> wrote the original Perl
module. Please don't send mail concerning Text::CSV_XS to Alan, as
he's not involved in the C part which is now the main part of the
module.

Jochen Wiedmann F<E<lt>joe@ispsoft.deE<gt>> rewrote the encoding and
decoding in C by implementing a simple finite-state machine and added
the variable quote, escape and separator characters, the binary mode
and the print and getline methods. See ChangeLog releases 0.10 through
0.23.

H.Merijn Brand F<E<lt>h.m.brand@xs4all.nlE<gt>> cleaned up the code,
added the field flags methods, wrote the major part of the test suite,
completed the documentation, fixed some RT bugs. See ChangeLog releases
0.25 and on.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007-2007 H.Merijn Brand for PROCURA B.V.
Copyright (C) 1998-2001 Jochen Wiedmann. All rights reserved.
Portions Copyright (C) 1997 Alan Citterman. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
